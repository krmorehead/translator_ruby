# frozen_string_literal: true

module Execution
  # Prompt for Sisyphus agent in conversational mode.
  # Has access to execution tools: file_tree, grep, read_file, write_file, bash.
  # Can explore, modify files, and execute commands.
  #
  class SisyphusChatPrompt < ToolCallPrompt
    attr_reader :path, :conversation_history

    # @param path [String] Codebase root for exploration and modification
    # @param conversation_history [Array<Hash>] Previous messages in conversation
    def initialize(path:, conversation_history: [])
      validate_params!(path)
      
      @path = path
      @conversation_history = conversation_history
      
      # Define Sisyphus's execution tools directly
      tools = [
        Tool.new(name: "file_tree", description: FileTreeTool.description, parameters: FileTreeTool.parameters_schema),
        Tool.new(name: "grep", description: GrepTool.description, parameters: GrepTool.parameters_schema),
        Tool.new(name: "read_file", description: ReadFileTool.description, parameters: ReadFileTool.parameters_schema),
        Tool.new(name: "write_file", description: Sisyphus::WriteFileTool.description, parameters: Sisyphus::WriteFileTool.parameters_schema),
        Tool.new(name: "bash", description: Sisyphus::BashTool.description, parameters: Sisyphus::BashTool.parameters_schema)
      ]
      
      # Call super with tools - ToolCallPrompt handles tool setup
      super(tools: tools)
    end

    def system_message
      <<~PROMPT
        You are Sisyphus, a code execution agent with the ability to explore and modify codebases.
        
        Available tools:
        - file_tree(path, max_depth): List directory structure (use relative paths like "app/services")
        - grep(pattern, path): Search for code patterns (use relative paths or "." for root)
        - read_file(file_path): Read file contents (use relative paths like "app/models/user.rb")
        - write_file(path, content): Create or modify files (use relative paths)
        - bash(command): Execute shell commands (runs in project root)
        
        When working with code:
        - Explore first to understand the context
        - Make precise, targeted changes
        - Always verify changes by reading files or running tests
        - Use bash to run syntax checks, tests, or other commands
        - Explain what you're doing and why
        
        When creating or modifying files:
        - Follow existing code patterns and conventions
        - Write clean, well-documented code
        - Include appropriate error handling
        - Consider edge cases
        
        You are conversational and helpful. Show your work and explain your reasoning.
      PROMPT
    end

    # Build messages including conversation history
    # @return [Array<Hash>] Messages for LLM
    def build_messages_with_history
      messages = [{ role: "system", content: system_message }]
      
      # Add conversation history
      @conversation_history.each do |msg|
        messages << { role: msg[:role], content: msg[:content] }
      end
      
      messages
    end

    # Override response_schema to return nil for conversational text
    def response_schema
      nil
    end
    
    # Override execute_with_tools to track file changes
    # @param user_message [String] User's message
    # @param max_iterations [Integer] Maximum tool calling iterations
    # @return [Hash] Final response with :content, :tool_calls, :file_changes
    def execute_with_tools(user_message:, max_iterations: 10)
      @file_changes = []
      result = super(user_message: user_message, max_iterations: max_iterations)
      result.merge(file_changes: @file_changes)
    end
    
    # Execute a tool (Sisyphus uses exploration + execution tools)
    # All Sisyphus tools take codebase_path and handle path resolution internally
    # @param name [String] Tool name
    # @param args [Hash] Tool arguments (symbolized keys)
    # @return [Hash] Tool result
    def execute_tool(name, args)
      # Track file changes for write_file
      if name == "write_file"
        # Track with full path for file_changes
        full_path = File.join(@path, args[:path])
        @file_changes << {
          path: full_path,
          action: "write"
        }
      end
      
      # Add codebase_path to args - Sisyphus tools handle path resolution
      enriched_args = args.merge(codebase_path: @path)
      
      tool_class = case name
      when "file_tree"
        Sisyphus::FileTreeTool
      when "grep"
        Sisyphus::GrepTool
      when "read_file"
        Sisyphus::ReadFileTool
      when "write_file"
        Sisyphus::WriteFileTool
      when "bash"
        Sisyphus::BashTool
      else
        raise ArgumentError, "Unknown Sisyphus tool: #{name}"
      end
      
      tool = tool_class.new
      tool.execute(**enriched_args)
    end

    private

    def validate_params!(path)
      raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
      raise ArgumentError, "path cannot be empty" if path.strip.empty?
    end
  end
end

