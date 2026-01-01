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

    # Default max entries when condensing
    DEFAULT_CONDENSE_LIMIT = 10

    attr_reader :entries, :sub_contexts, :condensed_context

    def initialize
      @entries = []
      @topic_index = Hash.new { |h, k| h[k] = Set.new }  # topic -> entry_ids
      @sub_contexts = {}  # name -> Context instance
      @condensed_context = nil
    end

    # Add a context entry with explicit topics
    # @param content [String] The context content
    # @param topics [Array<String>] Topics this context relates to
    # @param source [String] Where this context came from (file, question, etc)
    # @param metadata [Hash] Additional metadata
    # @return [Entries::BaseEntry] The created entry
    def add(content:, topics:, source:, metadata: {})
      entry = Entries::BaseEntry.new(
        content: content,
        topics: topics,
        source: source,
        metadata: metadata || {}
      )

      add_entry(entry)
    end

    # Add an existing entry object to the context
    # @param entry [Entries::BaseEntry] The entry to add
    # @return [Entries::BaseEntry] The added entry
    def add_entry(entry)
      @entries << entry

      # Index by topics for fast lookup
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end

      entry
    end

    # Get context entries relevant to a question/topic
    # Uses vector similarity for relevance scoring
    # @param question [String] The question to find relevant context for
    # @param limit [Integer] Maximum entries to return
    # @return [Array<Entry>] Relevant entries, sorted by relevance
    def relevant_to(question, limit: MAX_PROMPT_ENTRIES)
      return [] if @entries.empty?

      question_keywords = extract_keywords(question)
      return @entries.last(limit) if question_keywords.empty?

      # Use vectorization service for similarity scoring
      vectorization_service = VectorizationService.new
      query_text = question_keywords.join(" ")
      query_embedding = vectorization_service.vectorize(text: query_text)

      # Score entries by vector similarity
      scored = candidates_for_relevance.map do |entry|
        entry_keywords = extract_keywords(entry.content)
        entry_text = entry_keywords.join(" ")
        entry_embedding = vectorization_service.vectorize(text: entry_text)
        similarity = query_embedding.similarity_to(entry_embedding)
        { entry: entry, score: similarity }
      end

      # Return top scoring entries
      relevant = scored.sort_by { |s| -s[:score] }
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
    def self.from_h(data)
      context = new
      load_entries_from_h(context, data)
      load_sub_contexts_from_h(context, data)
      context
    end

    # Load from memory store section data
    # @param entries [Array<Entries::BaseEntry>] Array of Entry objects  
    # @param source [String] Where this data came from
    # @return [BaseContext] New context with entries
    def self.from_section_data(entries, source:)
      return new unless entries
      
      # Expect Array of Entry objects - no type checking!
      context = new
      entries.each { |entry| context.add_entry(entry) }
      context
    end

    # Helper to load entries from serialized data
    def self.load_entries_from_h(context, data)
      raise TypeError, "data must be a Hash" unless data.is_a?(Hash)
      raise ArgumentError, "data must contain :entries key" unless data.key?(:entries)
      raise TypeError, "entries must be an Array" unless data[:entries].is_a?(Array)

      entries_data = data[:entries]
      entries_data.each do |entry_data|
        raise TypeError, "each entry must be a Hash" unless entry_data.is_a?(Hash)
        
        entry = Entries::BaseEntry.from_h(entry_data)
        context.instance_variable_get(:@entries) << entry
        entry.topics.each do |topic|
          context.instance_variable_get(:@topic_index)[topic].add(entry.id)
        end
      end
    end

    # Helper to load sub-contexts from serialized data
    def self.load_sub_contexts_from_h(context, data)
      sub_contexts_data = data[:sub_contexts] || {}
      sub_contexts_data.each do |name, sub_data|
        class_name = sub_data[:context_class]
        sub_class = resolve_context_class(class_name)
        sub_context = sub_class.from_h(sub_data)
        context.add_sub_context(name, sub_context)
      end
    end

    # Resolve a context class from its name
    def self.resolve_context_class(class_name)
      return BaseContext unless class_name

      class_name.constantize
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

    # Subclasses can override to change candidate selection
    def candidates_for_relevance
      @entries.last(MAX_CANDIDATE_ENTRIES)
    end

    
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
