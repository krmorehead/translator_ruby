# frozen_string_literal: true

module Planning
  # Prompt for Daedalus agent in conversational mode.
  # Similar to PlanGenerationPrompt but for answering questions and exploring codebases.
  # Has access to exploration tools: file_tree, grep, read_file.
  #
  class DaedalusChatPrompt < ToolCallPrompt
    attr_reader :path, :conversation_history

    # @param path [String] Codebase root for exploration
    # @param conversation_history [Array<Hash>] Previous messages in conversation
    def initialize(path:, conversation_history: [])
      validate_params!(path)
      
      @path = path
      @conversation_history = conversation_history
      
      # Define Daedalus's exploration tools directly
      tools = [
        Tool.new(name: "file_tree", description: FileTreeTool.description, parameters: FileTreeTool.parameters_schema),
        Tool.new(name: "grep", description: GrepTool.description, parameters: GrepTool.parameters_schema),
        Tool.new(name: "read_file", description: ReadFileTool.description, parameters: ReadFileTool.parameters_schema)
      ]
      
      # Call super with tools - ToolCallPrompt handles tool setup
      super(tools: tools)
    end

    def system_message
      <<~PROMPT
        You are Daedalus, an expert software architect with deep codebase exploration capabilities.
        
        Available tools:
        - file_tree(path, max_depth): List directory structure (use relative paths like "app/services")
        - grep(pattern, path): Search for code patterns (use relative paths or "." for root)
        - read_file(file_path): Read file contents (use relative paths like "app/models/user.rb")
        
        When answering questions:
        - Use tools to gather accurate information from the codebase
        - Reference specific files and line numbers when relevant
        - Explain architectural patterns you discover
        - Provide concrete examples from the code
        - Be thorough but concise
        
        You are conversational and helpful. Answer questions directly while showing your exploration process.
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
    
    # Execute a tool (Daedalus uses exploration tools only)
    # Automatically prepends project path to relative paths
    # @param name [String] Tool name
    # @param args [Hash] Tool arguments (symbolized keys)
    # @return [Hash] Tool result
    def execute_tool(name, args)
      # Resolve relative paths to absolute paths based on project root
      resolved_args = resolve_paths(args, name)
      
      tool_class = case name
      when "file_tree"
        FileTreeTool
      when "grep"
        GrepTool
      when "read_file"
        ReadFileTool
      else
        raise ArgumentError, "Unknown Daedalus tool: #{name}"
      end
      
      tool = tool_class.new
      tool.execute(**resolved_args)
    end
    
    # Resolve relative paths to absolute paths
    # @param args [Hash] Tool arguments
    # @param tool_name [String] Name of the tool
    # @return [Hash] Arguments with resolved paths
    def resolve_paths(args, tool_name)
      resolved = args.dup
      
      # Convert relative paths to absolute paths
      if resolved[:path] && !resolved[:path].start_with?('/')
        resolved[:path] = File.join(@path, resolved[:path])
      end
      
      if resolved[:file_path] && !resolved[:file_path].start_with?('/')
        resolved[:file_path] = File.join(@path, resolved[:file_path])
      end
      
      resolved
    end

    private

    def validate_params!(path)
      raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
      raise ArgumentError, "path cannot be empty" if path.strip.empty?
    end
  end
end

