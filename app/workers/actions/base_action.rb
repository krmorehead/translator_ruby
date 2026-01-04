# frozen_string_literal: true

module Actions
  # Base class for all agent actions
  # Actions wrap tools and provide a consistent interface for agent execution
  class BaseAction
    attr_reader :agent, :memory_store, :goal
    
    def initialize(agent:, memory_store:, goal:)
      @agent = agent
      @memory_store = memory_store
      @goal = goal
    end
    
    # Execute the action with given arguments
    # @return [Hash] Result with :success, :result, :summary keys
    def execute(**args)
      raise NotImplementedError, "#{self.class.name} must implement #execute"
    end
    
    protected
    
    # Helper to build success result
    # Merges provided data into a success response
    def success_result(**data)
      {
        success: true,
        timestamp: Time.now.utc.iso8601
      }.merge(data)
    end
    
    # Helper to build error result
    def error_result(message)
      {
        success: false,
        result: nil,
        error: message,
        summary: "Error: #{message}"
      }
    end
    
    # Get the working directory path from agent
    # Note: This is the working directory (where agent investigates/modifies),
    # NOT the storage directory (which is always AgentConfig.data_path)
    def path
      @agent.respond_to?(:path) ? @agent.path : AgentConfig.data_path
    end
    
    # List files in a directory using FileTreeTool
    def list_files(dir_path = nil, pattern: "**/*")
      base = dir_path.nil? ? path : (dir_path.start_with?("/") ? dir_path : File.join(path, dir_path))
      Dir.glob(File.join(base, pattern)).select { |f| File.file?(f) }
    end
    
    # Read file contents using ReadFileTool
    def read_file(file_path)
      full_path = file_path.start_with?("/") ? file_path : File.join(path, file_path)
      File.read(full_path)
    rescue Errno::ENOENT
      ""
    end
    
    # Search file contents using GrepTool
    def grep_files(pattern, file_pattern: "**/*.rb")
      matches = []
      list_files(nil, pattern: file_pattern).each do |file_path|
        content = read_file(file_path)
        content.each_line.with_index do |line, index|
          if line =~ /#{pattern}/
            matches << {
              file: file_path,
              line: index + 1,
              content: line.strip
            }
          end
        end
      end
      matches
    end
    
    # Record a discovered file to memory
    def record_discovered_file(file_path:, relevance:, reasoning:)
      return unless @memory_store.respond_to?(:record_discovered_file)
      @memory_store.record_discovered_file(
        file_path: file_path,
        relevance: relevance,
        reasoning: reasoning
      )
    end
    
    # Record a finding to memory
    def record_finding(text:, source:, confidence:, metadata: {})
      return unless @memory_store.respond_to?(:record_finding)
      @memory_store.record_finding(
        text: text,
        source: source,
        confidence: confidence,
        metadata: metadata
      )
    end
  end
end
