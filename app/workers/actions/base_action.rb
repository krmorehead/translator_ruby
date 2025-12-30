# frozen_string_literal: true

module Actions
  # Base class for all agent actions.
  # Actions are small, composable units of work that can be executed by an agent.
  #
  # Subclasses must implement:
  # - #execute(**arguments) - Perform the action and return a result hash
  #
  # Subclasses can optionally define:
  # - self.description - Human-readable description for the planner
  # - self.parameters - Parameter definitions for the action
  # - self.category - Category for grouping related actions
  #
  # @example Creating a custom action
  #   class SearchFilesAction < Actions::BaseAction
  #     def self.description
  #       "Search for files matching a pattern in the codebase"
  #     end
  #
  #     def self.parameters
  #       {
  #         pattern: { type: :string, required: true, description: "Search pattern" },
  #         path: { type: :string, required: false, description: "Directory to search" }
  #       }
  #     end
  #
  #     def execute(pattern:, path: nil)
  #       files = search_files(pattern, path)
  #       success_result(files: files, count: files.size)
  #     end
  #   end
  #
  class BaseAction
    attr_reader :agent, :memory_store, :path, :goal

    class << self
      # Human-readable description of what this action does
      # @return [String]
      def description
        name.demodulize.underscore.humanize
      end

      # Parameter definitions for this action
      # @return [Hash] Parameter name => definition
      def parameters
        {}
      end

      # Category for grouping related actions
      # @return [Symbol]
      def category
        :general
      end

      # Validate that required parameters are present
      # @param arguments [Hash] The arguments to validate
      # @raise [ArgumentError] If required parameters are missing
      def validate_parameters!(arguments)
        parameters.each do |name, config|
          if config[:required] && !arguments.key?(name)
            raise ArgumentError, "Required parameter '#{name}' is missing"
          end
        end
      end
    end

    # Initialize an action instance
    # @param agent [AgentWorker] The agent executing this action
    # @param memory_store [ResearchMemoryStore] Memory store for persistence
    # @param path [String] Working path (e.g., codebase root)
    # @param goal [String] The overall goal being pursued
    def initialize(agent:, memory_store:, path:, goal:)
      @agent = agent
      @memory_store = memory_store
      @path = path
      @goal = goal
    end

    # Execute the action
    # @param arguments [Hash] Action-specific arguments
    # @return [Hash] Result hash with :success key and action-specific data
    def execute(**arguments)
      raise NotImplementedError, "#{self.class.name} must implement #execute"
    end

    
    # Build a successful result
    # @param data [Hash] Result data
    # @return [Hash] Success result
    def success_result(**data)
      {
        success: true,
        action: self.class.name.demodulize.underscore,
        timestamp: Time.now.utc.iso8601
      }.merge(data)
    end

    # Build a failure result
    # @param error [String, Exception] Error message or exception
    # @param data [Hash] Additional data
    # @return [Hash] Failure result
    def failure_result(error, **data)
      error_message = error.respond_to?(:message) ? error.message : error.to_s
      {
        success: false,
        error: error_message,
        action: self.class.name.demodulize.underscore,
        timestamp: Time.now.utc.iso8601
      }.merge(data)
    end

    # Build a partial result (action completed but with warnings)
    # @param warnings [Array<String>] Warning messages
    # @param data [Hash] Result data
    # @return [Hash] Partial success result
    def partial_result(warnings:, **data)
      {
        success: true,
        partial: true,
        warnings: warnings,
        action: self.class.name.demodulize.underscore,
        timestamp: Time.now.utc.iso8601
      }.merge(data)
    end

    # Record a finding to memory
    # @param text [String] The finding text
    # @param source [String] Source of the finding (e.g., file path)
    # @param confidence [Float] Confidence score (0.0-1.0)
    # @param metadata [Hash] Additional metadata
    def record_finding(text:, source: nil, confidence: 1.0, metadata: {})
      finding = {
        id: SecureRandom.uuid,
        text: text,
        source: source || self.class.name.demodulize.underscore,
        confidence: confidence,
        action: self.class.name.demodulize.underscore,
        timestamp: Time.now.utc.iso8601
      }.merge(metadata)

      memory_store.update_section(name: :findings, content: finding, append: true)
      finding
    end

    # Record that a file was discovered/analyzed
    # @param file_path [String] Path to the file
    # @param relevance [Float] Relevance score
    # @param reasoning [String] Why this file is relevant
    def record_discovered_file(file_path:, relevance: 0.5, reasoning: nil)
      entry = {
        id: SecureRandom.uuid,
        path: file_path,
        relevance_score: relevance,
        reasoning: reasoning,
        analyzed: false,
        discovered_at: Time.now.utc.iso8601,
        timestamp: Time.now.utc.iso8601
      }

      memory_store.update_section(name: :discovered_files, content: entry, append: true)
      entry
    end

    # Check if a file has already been analyzed
    # @param file_path [String] Path to check
    # @return [Boolean]
    def file_already_analyzed?(file_path)
      files = memory_store.get_section(:discovered_files)
      files.any? { |f| f[:path] == file_path && f[:analyzed] }
    end

    # Mark a file as analyzed
    # @param file_path [String] Path to mark
    def mark_file_analyzed(file_path)
      files = memory_store.get_section(:discovered_files)
      file_entry = files.find { |f| f[:path] == file_path }

      if file_entry
        file_entry[:analyzed] = true
        file_entry[:analyzed_at] = Time.now.utc.iso8601
        memory_store.set_section(:discovered_files, files)
      end
    end

    # Read a file from the path
    # @param file_path [String] Path to the file (relative to @path or absolute)
    # @return [String, nil] File contents or nil if file doesn't exist
    def read_file(file_path)
      full_path = file_path.start_with?("/") ? file_path : File.join(path, file_path)
      return nil unless File.exist?(full_path) && File.readable?(full_path)

      File.read(full_path)
    end

    # List files in a directory
    # @param dir_path [String] Directory path (relative to @path or absolute)
    # @param pattern [String] Glob pattern (default: "**/*")
    # @return [Array<String>] List of file paths
    def list_files(dir_path = nil, pattern: "**/*")
      base = dir_path.nil? ? path : (dir_path.start_with?("/") ? dir_path : File.join(path, dir_path))
      Dir.glob(File.join(base, pattern)).select { |f| File.file?(f) }
    end

    # Search file contents using grep
    # @param pattern [String] Search pattern (regex)
    # @param file_pattern [String] File glob pattern
    # @return [Array<Hash>] Matches with file, line, and content
    def grep_files(pattern, file_pattern: "**/*.rb")
      matches = []
      files = list_files(nil, pattern: file_pattern)

      files.each do |file_path|
        content = File.read(file_path)

        content.each_line.with_index do |line, index|
          if line =~ /#{pattern}/i
            matches << {
              file: file_path,
              line_number: index + 1,
              content: line.strip,
              match: $&
            }
          end
        end
      end

      matches
    end
  end
end
