# frozen_string_literal: true

module Contexts
  # Abstract base class for context management.
  # Provides topic-aware relevance filtering for prompt context.
  #
  # Context entries are not compressed or deleted - full history is retained.
  # Only RELEVANT entries are passed to prompts based on the current question.
  #
  # Supports nesting via sub_contexts - each sub-context is a named child Context.
  # Serialization recursively handles sub_contexts for graceful persistence.
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

    # Default max entries when condensing
    DEFAULT_CONDENSE_LIMIT = 10

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

    attr_reader :entries, :sub_contexts

    def initialize
      @entries = []
      @topic_index = Hash.new { |h, k| h[k] = Set.new }  # topic -> entry_ids
      @sub_contexts = {}  # name -> Context instance
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
    # Recursively serializes sub_contexts
    # @return [Hash] Serialized context data
    def to_h
      {
        context_class: self.class.name,
        entries: @entries.map(&:to_h),
        topic_index: @topic_index.transform_values(&:to_a),
        sub_contexts: @sub_contexts.transform_values(&:to_h)
      }
    end

    # Compute a deterministic hash of the context state
    # Useful for cache keys and change detection
    # @return [String] MD5 hash of the context
    def compute_hash
      content = {
        entry_count: @entries.size,
        last_entry_id: @entries.last&.id,
        last_entry_content: @entries.last&.content&.first(100),
        sub_context_keys: @sub_contexts.keys.sort
      }
      Digest::MD5.hexdigest(content.to_json)
    end

    # Load from hash
    # Recursively deserializes sub_contexts
    # @param data [Hash] Serialized context data
    # @param context_registry [Hash] Optional mapping of class names to classes for sub-contexts
    # @return [BaseContext] Deserialized context
    def self.from_h(data, context_registry: nil)
      context = new
      load_entries_from_h(context, data)
      load_sub_contexts_from_h(context, data, context_registry)
      context
    end

    # Load from memory store section data
    # Data format: Hash with :context_class = serialized context, Array = raw entries
    def self.from_section_data(data, source:)
      return new unless data

      # Try to extract context_class - works for Hash, fails for Array
      context_class_name = begin
        data[:context_class]
      rescue TypeError
        nil
      end

      if context_class_name
        klass = resolve_context_class(context_class_name, nil)
        return klass.from_h(data)
      end

      # Raw entries array
      context = new
      Array(data).each { |entry| context.add_from_entry(entry, source: source) }
      context
    end

    # Helper to load entries from serialized data
    def self.load_entries_from_h(context, data)
      entries_data = data[:entries] || []
      entries_data.each do |entry_data|
        entry = Entry.new(
          id: entry_data[:id],
          content: entry_data[:content],
          topics: entry_data[:topics] || [],
          source: entry_data[:source],
          timestamp: entry_data[:timestamp],
          metadata: entry_data[:metadata] || {}
        )
        context.instance_variable_get(:@entries) << entry
        entry.topics.each do |topic|
          context.instance_variable_get(:@topic_index)[topic].add(entry.id)
        end
      end
    end

    # Helper to load sub-contexts from serialized data
    def self.load_sub_contexts_from_h(context, data, context_registry)
      sub_contexts_data = data[:sub_contexts] || {}
      sub_contexts_data.each do |name, sub_data|
        class_name = sub_data[:context_class]
        sub_class = resolve_context_class(class_name, context_registry)
        sub_context = sub_class.from_h(sub_data, context_registry: context_registry)
        context.add_sub_context(name, sub_context)
      end
    end

    # Resolve a context class from its name
    def self.resolve_context_class(class_name, context_registry)
      return BaseContext unless class_name

      context_registry&.fetch(class_name, nil) || class_name.constantize
    end

    # Get size of context store
    def size
      @entries.size
    end

    # Add an entry from memory store data
    # @param entry [Hash] Entry with :text and optional :tags
    # @param source [String] The source/section name
    def add_from_entry(entry, source:)
      add(
        content: entry[:text],
        topics: Array(entry[:tags]) << source,
        source: source,
        metadata: entry
      )
    end

    # Add a named sub-context for nesting
    # @param name [String, Symbol] The name/key for this sub-context
    # @param context [BaseContext] The context to nest
    # @return [BaseContext] The added context
    def add_sub_context(name, context)
      raise ArgumentError, "context must be a BaseContext" unless context.is_a?(BaseContext)

      @sub_contexts[name.to_sym] = context
      context
    end

    # Get a named sub-context
    # @param name [String, Symbol] The name/key for the sub-context
    # @return [BaseContext, nil] The sub-context or nil
    def get_sub_context(name)
      @sub_contexts[name.to_sym]
    end

    # Check if a sub-context exists
    # @param name [String, Symbol] The name/key for the sub-context
    # @return [Boolean]
    def has_sub_context?(name)
      @sub_contexts.key?(name.to_sym)
    end

    # Condense context by keeping only the most relevant entries per topic
    # Creates a new condensed context - does not mutate self
    # @param max_entries [Integer] Maximum entries to keep
    # @param condense_sub_contexts [Boolean] Whether to also condense sub-contexts
    # @return [BaseContext] A new condensed context
    def condense(max_entries: DEFAULT_CONDENSE_LIMIT, condense_sub_contexts: true)
      condensed = self.class.new

      # Group entries by primary topic and keep most recent per topic
      by_topic = @entries.group_by { |e| e.topics.first || "general" }

      # Calculate how many entries per topic we can keep
      entries_per_topic = [1, max_entries / [by_topic.size, 1].max].max

      selected_entries = by_topic.flat_map do |_topic, topic_entries|
        topic_entries.last(entries_per_topic)
      end

      # If we still have too many, take the most recent
      selected_entries = selected_entries.last(max_entries)

      # Add entries to condensed context
      selected_entries.each do |entry|
        condensed.add(
          content: entry.content,
          topics: entry.topics,
          source: entry.source,
          metadata: entry.metadata.merge(condensed_from: entry.id)
        )
      end

      # Optionally condense sub-contexts
      if condense_sub_contexts
        @sub_contexts.each do |name, sub_ctx|
          condensed.add_sub_context(name, sub_ctx.condense(max_entries: max_entries))
        end
      else
        @sub_contexts.each do |name, sub_ctx|
          condensed.add_sub_context(name, sub_ctx)
        end
      end

      condensed
    end

    # Merge another context into this one
    # Combines entries and sub-contexts intelligently
    # @param other [BaseContext] The context to merge in
    # @param deduplicate [Boolean] Whether to skip entries with matching content
    # @return [self] Returns self for chaining
    def merge(other, deduplicate: true)
      raise ArgumentError, "other must be a BaseContext" unless other.is_a?(BaseContext)

      existing_content = deduplicate ? @entries.map(&:content).to_set : Set.new

      other.entries.each do |entry|
        next if deduplicate && existing_content.include?(entry.content)

        add(
          content: entry.content,
          topics: entry.topics,
          source: entry.source,
          metadata: entry.metadata.merge(merged_from: other.class.name)
        )
      end

      # Merge sub-contexts recursively
      other.sub_contexts.each do |name, sub_ctx|
        if @sub_contexts.key?(name)
          @sub_contexts[name].merge(sub_ctx, deduplicate: deduplicate)
        else
          @sub_contexts[name] = sub_ctx
        end
      end

      self
    end

    # Get all entries including from sub-contexts
    # @param depth [Integer] Maximum depth to traverse (-1 for unlimited)
    # @return [Array<Entry>] All entries flattened
    def all_entries(depth: -1)
      result = @entries.dup

      return result if depth == 0

      @sub_contexts.each_value do |sub_ctx|
        result.concat(sub_ctx.all_entries(depth: depth - 1))
      end

      result
    end

    # Get relevant entries including from sub-contexts
    # @param question [String] The question to find relevant context for
    # @param limit [Integer] Maximum entries to return
    # @param include_sub_contexts [Boolean] Whether to search sub-contexts
    # @return [Array<Entry>] Relevant entries
    def relevant_to_deep(question, limit: MAX_PROMPT_ENTRIES, include_sub_contexts: true)
      all_scored = []

      question_keywords = extract_keywords(question)

      # Score entries from this context
      candidates_for_relevance.each do |entry|
        score = calculate_relevance_score(entry, question_keywords)
        all_scored << { entry: entry, score: score, source: :self }
      end

      # Score entries from sub-contexts
      if include_sub_contexts
        @sub_contexts.each do |name, sub_ctx|
          sub_ctx.candidates_for_relevance.each do |entry|
            score = sub_ctx.send(:calculate_relevance_score, entry, question_keywords)
            all_scored << { entry: entry, score: score, source: name }
          end
        end
      end

      # Take highest scoring entries
      all_scored
        .select { |s| s[:score] >= KEYWORD_RELEVANCE_THRESHOLD }
        .sort_by { |s| -s[:score] }
        .first(limit)
        .map { |s| s[:entry] }
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

