# frozen_string_literal: true

module Contexts
  # Abstract base class for context management.
  # Provides topic-aware relevance filtering for prompt context.
  #
  # Context entries are not compressed or deleted - full history is retained.
  # Only RELEVANT entries are passed to prompts based on the current question.
  #
  # Subclasses should implement domain-specific behavior while using
  # the common relevance filtering and topic indexing infrastructure.
  class BaseContext
    # Maximum entries to evaluate for relevance per prompt
    MAX_CANDIDATE_ENTRIES = 20

    # Maximum entries to include in any single prompt
    MAX_PROMPT_ENTRIES = 5

    # Minimum keyword overlap to consider relevant without LLM
    KEYWORD_RELEVANCE_THRESHOLD = 2

    Entry = Struct.new(:id, :content, :topics, :source, :timestamp, :metadata, keyword_init: true) do
      def to_h
        {
          id: id,
          content: content,
          topics: topics,
          source: source,
          timestamp: timestamp,
          metadata: metadata
        }
      end
    end

    attr_reader :entries

    def initialize
      @entries = []
      @topic_index = Hash.new { |h, k| h[k] = Set.new }  # topic -> entry_ids
    end

    # Add a context entry with explicit topics
    # @param content [String] The context content
    # @param topics [Array<String>] Topics this context relates to
    # @param source [String] Where this context came from (file, question, etc)
    # @param metadata [Hash] Additional metadata
    # @return [Entry] The created entry
    def add(content:, topics:, source:, metadata: {})
      entry = Entry.new(
        id: SecureRandom.uuid,
        content: content,
        topics: normalize_topics(topics),
        source: source,
        timestamp: Time.now.utc.iso8601,
        metadata: metadata || {}
      )

      @entries << entry

      # Index by topics for fast lookup
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end

      entry
    end

    # Get context entries relevant to a question/topic
    # Uses deterministic keyword matching
    # @param question [String] The question to find relevant context for
    # @param limit [Integer] Maximum entries to return
    # @return [Array<Entry>] Relevant entries, most relevant first
    def relevant_to(question, limit: MAX_PROMPT_ENTRIES)
      return [] if @entries.empty?

      question_keywords = extract_keywords(question)
      return @entries.last(limit) if question_keywords.empty?

      # Score entries by keyword overlap with question
      scored = candidates_for_relevance.map do |entry|
        score = calculate_relevance_score(entry, question_keywords)
        { entry: entry, score: score }
      end

      # Take entries with sufficient overlap
      relevant = scored.select { |s| s[:score] >= KEYWORD_RELEVANCE_THRESHOLD }
                       .sort_by { |s| -s[:score] }
                       .first(limit)
                       .map { |s| s[:entry] }

      # If we don't have enough, add most recent entries
      if relevant.size < limit
        fill_with_recent(relevant, limit)
      else
        relevant
      end
    end

    # Get entries by topic (exact match)
    # @param topic [String] The topic to filter by
    # @return [Array<Entry>] Entries tagged with this topic
    def by_topic(topic)
      entry_ids = @topic_index[topic.downcase]
      @entries.select { |e| entry_ids.include?(e.id) }
    end

    # Format relevant context for inclusion in a prompt
    # @param question [String] The question to find relevant context for
    # @param format [Symbol] Output format (:brief, :detailed)
    # @return [String] Formatted context string
    def format_for_prompt(question, format: :brief)
      relevant = relevant_to(question)
      return "" if relevant.empty?

      case format
      when :brief
        relevant.map { |e| "- #{e.content}" }.join("\n")
      when :detailed
        relevant.map do |e|
          "Source: #{e.source}\nTopics: #{e.topics.join(', ')}\n#{e.content}"
        end.join("\n\n")
      else
        relevant.map(&:content).join("\n")
      end
    end

    # Get a compressed summary of all context
    # Groups by topic and takes most recent content per topic
    # @return [String] Compressed summary
    def compressed_summary
      return "" if @entries.empty?

      by_primary_topic = @entries.group_by { |e| e.topics.first || "general" }

      summaries = by_primary_topic.map do |topic, topic_entries|
        latest = topic_entries.last
        "#{topic}: #{truncate(latest.content, 200)}"
      end

      summaries.join("\n")
    end

    # Serialize to hash for persistence
    def to_h
      {
        entries: @entries.map(&:to_h),
        topic_index: @topic_index.transform_values(&:to_a)
      }
    end

    # Load from hash
    def self.from_h(data)
      context = new
      (data[:entries] || data["entries"] || []).each do |entry_data|
        entry = Entry.new(
          id: entry_data[:id] || entry_data["id"],
          content: entry_data[:content] || entry_data["content"],
          topics: entry_data[:topics] || entry_data["topics"] || [],
          source: entry_data[:source] || entry_data["source"],
          timestamp: entry_data[:timestamp] || entry_data["timestamp"],
          metadata: entry_data[:metadata] || entry_data["metadata"] || {}
        )
        context.instance_variable_get(:@entries) << entry
        entry.topics.each do |topic|
          context.instance_variable_get(:@topic_index)[topic].add(entry.id)
        end
      end
      context
    end

    # Get size of context store
    def size
      @entries.size
    end

    protected

    # Subclasses can override to provide custom keyword extraction
    def extract_keywords(text)
      return [] if text.nil?

      stop_words = %w[
        the a an is are was were what how why when where which who whom whose
        if then else do does did has have had been being be this that these those
        it its for to from with at by on in of and or but not
      ]

      text
        .to_s
        .downcase
        .gsub(/[^a-z0-9\s]/, " ")
        .split
        .reject { |w| stop_words.include?(w) || w.length < 3 }
        .uniq
    end

    # Subclasses can override for custom relevance scoring
    def calculate_relevance_score(entry, question_keywords)
      entry_keywords = extract_keywords(entry.content)
      topic_keywords = entry.topics.flat_map { |t| extract_keywords(t) }
      all_entry_keywords = (entry_keywords + topic_keywords).uniq

      (question_keywords & all_entry_keywords).size
    end

    # Subclasses can override to change candidate selection
    def candidates_for_relevance
      @entries.last(MAX_CANDIDATE_ENTRIES)
    end

    private

    def normalize_topics(topics)
      Array(topics).map { |t| t.to_s.downcase.strip }.reject(&:empty?)
    end

    def fill_with_recent(relevant, limit)
      recent = @entries.last(limit - relevant.size)
      relevant_ids = relevant.map(&:id)
      additional = recent.reject { |e| relevant_ids.include?(e.id) }
      (relevant + additional).first(limit)
    end

    def truncate(text, max_length)
      return text if text.length <= max_length

      text[0, max_length - 3] + "..."
    end
  end
end

