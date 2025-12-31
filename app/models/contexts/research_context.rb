# frozen_string_literal: true

module Contexts
  # Research-specific context that tracks findings, sub-questions, and file analyses.
  # Extends BaseContext with research-aware relevance filtering.
  #
  # Key features:
  # - Tracks sub-questions as first-class topics
  # - Links findings to files and questions
  # - Provides specialized formatting for research prompts
  class ResearchContext < BaseContext
    # Research-specific topic prefixes for better indexing
    TOPIC_PREFIXES = {
      question: "q:",
      file: "file:",
      finding: "finding:",
      method: "method:",
      class: "class:"
    }.freeze

    attr_reader :research_goal, :findings_list, :sub_questions_list, :file_summaries_list

    def initialize(research_goal: nil)
      super()
      @research_goal = research_goal
      @goal_keywords = research_goal ? extract_keywords(research_goal) : []
      
      # Dedicated collections for research entities
      @findings_list = []
      @sub_questions_list = []
      @file_summaries_list = []
    end

    # Add a finding from code analysis
    # @param finding [String] The finding text
    # @param file_path [String] Path to the source file
    # @param sub_question [String] The sub-question this finding addresses
    # @param confidence [Float] Confidence score (0-1)
    # @return [Entries::ResearchEntry]
    def add_finding(finding:, file_path:, sub_question:, confidence: 0.5)
      topics = build_topics_for_finding(file_path, sub_question)

      entry = Entries::ResearchEntry.new(
        finding: finding,
        file_path: file_path,
        sub_question: sub_question,
        confidence: confidence,
        topics: topics,
        source: file_path,
        metadata: {}
      )
      
      @findings_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add a sub-question from goal decomposition
    # @param question [String] The sub-question text
    # @param parent_question [String] Parent question if any
    # @param priority [Integer] Priority level
    # @return [Entries::BaseEntry]
    def add_sub_question(question:, parent_question: nil, priority: 1)
      topics = ["#{TOPIC_PREFIXES[:question]}#{normalize_question(question)}"]
      topics << "#{TOPIC_PREFIXES[:question]}#{normalize_question(parent_question)}" if parent_question

      entry = Entries::BaseEntry.new(
        content: question,
        topics: topics,
        source: "goal_decomposition",
        metadata: {
          parent: parent_question,
          priority: priority
        }
      )
      
      @sub_questions_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add a file summary
    # @param file_path [String] Path to the file
    # @param summary [String] Summary of the file's purpose
    # @param methods [Array<String>] Key methods in the file
    # @return [Entries::BaseEntry]
    def add_file_summary(file_path:, summary:, methods: [])
      file_name = File.basename(file_path, ".*")
      topics = ["#{TOPIC_PREFIXES[:file]}#{file_name}"]
      methods.each { |m| topics << "#{TOPIC_PREFIXES[:method]}#{m}" }

      entry = Entries::BaseEntry.new(
        content: summary,
        topics: topics,
        source: file_path,
        metadata: { methods: methods }
      )
      
      @file_summaries_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Get context relevant to a specific sub-question
    # Prioritizes findings and file summaries tagged with this question
    # @param sub_question [String] The sub-question
    # @param limit [Integer] Maximum entries
    # @return [Array<Entry>]
    def for_sub_question(sub_question, limit: MAX_PROMPT_ENTRIES)
      question_topic = "#{TOPIC_PREFIXES[:question]}#{normalize_question(sub_question)}"

      # First, get entries explicitly tagged with this question
      tagged = by_topic(question_topic)

      if tagged.size >= limit
        return tagged.last(limit)
      end

      # Then supplement with relevance-based entries
      additional_needed = limit - tagged.size
      relevant = relevant_to(sub_question, limit: additional_needed)

      # Combine, avoiding duplicates
      tagged_ids = tagged.map(&:id)
      additional = relevant.reject { |e| tagged_ids.include?(e.id) }

      (tagged + additional).first(limit)
    end

    # Get context for analyzing a specific file
    # @param file_path [String] Path to the file
    # @param limit [Integer] Maximum entries
    # @return [Array<Entry>]
    def for_file(file_path, limit: MAX_PROMPT_ENTRIES)
      file_name = File.basename(file_path, ".*")
      file_topic = "#{TOPIC_PREFIXES[:file]}#{file_name}"

      # Get entries about this file
      about_file = by_topic(file_topic)

      if about_file.size >= limit
        return about_file.last(limit)
      end

      # Supplement with goal-relevant context
      additional = relevant_to(@research_goal || "", limit: limit - about_file.size)
      about_file_ids = about_file.map(&:id)
      extra = additional.reject { |e| about_file_ids.include?(e.id) }

      (about_file + extra).first(limit)
    end

    # Format context specifically for code analysis prompts
    # @param current_question [String] The current sub-question being investigated
    # @return [String] Formatted context
    def format_for_analysis(current_question)
      relevant = for_sub_question(current_question, limit: 3)
      return "" if relevant.empty?

      parts = ["Previous relevant findings:"]
      relevant.each do |entry|
        parts << "- #{entry.content}"
      end
      parts.join("\n")
    end

    # Format context for synthesis prompts
    # Groups findings by sub-question
    # @return [String] Formatted context
    def format_for_synthesis
      return "" if @findings_list.empty?

      by_question = @findings_list.group_by { |f| f.sub_question || "general" }

      parts = []
      by_question.each do |question, question_findings|
        parts << "## #{question}"
        question_findings.last(3).each do |f|
          conf = f.confidence || 0.5
          parts << "- (#{(conf * 100).round}%) #{f.content}"
        end
      end

      parts.join("\n")
    end

    # Get all findings
    # @return [Array<Entries::ResearchEntry>] All findings
    def findings
      @findings_list
    end
    
    # Get all sub-questions
    # @return [Array<Entries::BaseEntry>] All sub-questions
    def sub_questions
      @sub_questions_list
    end
    
    # Get all file summaries
    # @return [Array<Entries::BaseEntry>] All file summaries
    def file_summaries
      @file_summaries_list
    end
    
    # Override to boost relevance for goal-related keywords
    def calculate_relevance_score(entry, question_keywords)
      base_score = super

      # Boost entries that also match the overall research goal
      if @goal_keywords.any?
        entry_keywords = extract_keywords(entry.content)
        goal_overlap = (@goal_keywords & entry_keywords).size
        base_score + (goal_overlap * 0.5).round
      else
        base_score
      end
    end

    
    def build_topics_for_finding(file_path, sub_question)
      topics = []

      # Add file topic
      if file_path
        file_name = File.basename(file_path, ".*")
        topics << "#{TOPIC_PREFIXES[:file]}#{file_name}"
      end

      # Add question topic
      if sub_question
        topics << "#{TOPIC_PREFIXES[:question]}#{normalize_question(sub_question)}"
      end

      topics
    end

    def normalize_question(question)
      return "" unless question

      # Create a short key from the question
      extract_keywords(question).first(3).join("_")
    end
  end
end

