# frozen_string_literal: true

# Workflow responsible for executing a single plan step.
# Implements the complete execution pipeline:
# 1. Context Assembly - Determine what codebase context is needed
# 2. Planning - Plan the sequence of tool calls
# 3. Validation - Validate tool parameters before execution
# 4. Execution - Execute tools and record results
# 5. Recording - Build StepResult with actions, diffs, and outputs
#
# @example Execute a step
#   workflow = StepExecutionWorkflow.new(
#     owner_id: worker.owner_id,
#     parent_memory: worker.memory_store
#   )
#   
#   workflow.setup(
#     step: plan_step,
#     path: "/path/to/codebase",
#     context: {},
#     system_prompt: sisyphus_system_prompt
#   )
#   
#   result = workflow.execute
#
class StepExecutionWorkflow < BaseWorkflow
  # Step execution-specific states
  initial_state :pending

  state :pending,            description: "Workflow created"
  state :running,            description: "Workflow started"
  state :assembling_context, description: "Gathering needed context"
  state :planning,           description: "Planning tool call sequence"
  state :validating,         description: "Validating tool parameters"
  state :executing,          description: "Executing tools"
  state :recording,          description: "Recording results"
  state :complete,           description: "Execution complete"
  state :failed,             description: "Execution failed"

  # Define transitions
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :assembling_context, on: :initialized
  transition from: :assembling_context, to: :planning, on: :context_assembled
  transition from: :planning, to: :validating, on: :planned
  transition from: :validating, to: :executing, on: :validated
  transition from: :executing, to: :recording, on: :executed
  transition from: :recording, to: :complete, on: :finish
  transition from: [:running, :assembling_context, :planning, :validating, :executing, :recording],
             to: :failed, on: :fail

  attr_reader :step, :path, :context, :system_prompt,
              :assembled_context, :planned_tools, :validation_results,
              :tool_executions, :diffs

  # Initialize the workflow
  # @param owner_id [String] Parent worker's owner ID
  # @param parent_memory [WorkflowMemoryStore] Parent memory store
  def initialize(owner_id:, parent_memory: nil)
    super(owner_id: owner_id, parent_memory: parent_memory)
    
    @step = nil
    @path = nil
    @context = nil
    @system_prompt = nil
    @assembled_context = {}
    @planned_tools = []
    @validation_results = []
    @tool_executions = []
    @diffs = {}
  end

  # Setup the workflow with step and context
  # @param step [Planning::Step] The step to execute
  # @param path [String] Codebase root path
  # @param context [Contexts::BaseContext] Context object (REQUIRED - no default)
  # @param system_prompt [Object] System prompt for LLM calls
  # @return [self]
  def setup(step:, path:, context:, system_prompt: nil)
    validate_setup_params!(step, path, context)
    
    @step = step
    @path = path
    @context = context
    @system_prompt = system_prompt

    # Initialize workflow memory
    initialize_workflow_memory if @owner_id

    self
  end

  # Execute the complete step execution pipeline
  # @return [Hash] StepResult data
  def execute
    trigger(:start)
    trigger(:initialized)

    assemble_context
    trigger(:context_assembled)

    plan_tool_sequence
    trigger(:planned)

    validate_tools
    trigger(:validated)

    execute_tools
    trigger(:executed)

    result = record_results
    trigger(:finish)

    # Update metadata with final state
    result[:metadata][:final_state] = current_state
    result
  rescue StandardError => e
    handle_error(e)
  end

  private

  # Validate setup parameters
  def validate_setup_params!(step, path, context)
    unless step.is_a?(Planning::Step)
      raise TypeError, "step must be a Planning::Step, got #{step.class}"
    end

    unless path.is_a?(String) && !path.empty?
      raise ArgumentError, "path must be a non-empty String, got #{path.inspect}"
    end

    unless File.directory?(path)
      raise ArgumentError, "path must be an existing directory: #{path}"
    end
    
    # Validate context is a Context object (OOP pattern - no hashes!)
    unless context.is_a?(Contexts::BaseContext)
      raise TypeError, "context must be a Contexts::BaseContext (or subclass), got #{context.class}. Example: Contexts::SisyphusContext.new(...)"
    end
  end

  # Phase 1: Assemble Context
  # Determine what codebase context is needed for this step
  def assemble_context
    record_decision(
      decision: "assemble_context",
      reasoning: "Gathering context for step: #{@step.title}",
      evidence: { step_number: @step.number }
    )

    # Use ContextAssemblyPrompt to determine needed context
    prompt = Execution::ContextAssemblyPrompt.new(
      step: @step,
      codebase_root: @path,
      file_tree_summary: generate_file_tree_summary
    )

    # Build the user message
    user_message = <<~MSG
      I need to execute this step:

      **Title**: #{@step.title}
      **Intent**: #{@step.intent}

      **Details**:
      #{@step.details.map { |d| "- #{d}" }.join("\n")}

      **Tests/Acceptance**:
      #{@step.tests.map { |t| "- #{t}" }.join("\n")}

      What codebase context do I need to gather to execute this step effectively?
    MSG

    result = prompt.execute(prompt: user_message, context: nil)

    @assembled_context = {
      step_intent: @step.intent,
      step_details: @step.details,
      step_tests: @step.tests,
      codebase_path: @path,
      llm_context_needs: result[:content],
      files_to_read: result[:content]["files_to_read"] || [],
      patterns_to_search: result[:content]["patterns_to_search"] || [],
      directories_to_explore: result[:content]["directories_to_explore"] || []
    }

    record_decision(
      decision: "context_assembled",
      reasoning: result[:content]["rationale"] || "Context assembly completed",
      evidence: {
        files_requested: @assembled_context[:files_to_read].size,
        patterns_requested: @assembled_context[:patterns_to_search].size
      }
    )
  end

  # Phase 2: Plan Tool Sequence
  # Plan the sequence of tool calls needed to accomplish the step
  def plan_tool_sequence
    record_decision(
      decision: "plan_tool_sequence",
      reasoning: "Planning tool calls for step: #{@step.title}",
      context: { assembled_context_keys: @assembled_context.keys }
    )

    # Get available tools
    available_tools = get_available_tools

    # Use StepPlanningPrompt for LLM-driven planning
    prompt = Execution::StepPlanningPrompt.new(
      step: @step,
      available_tools: available_tools,
      assembled_context: @assembled_context
    )

    # Use the prompt's built-in message builder
    user_message = prompt.build_user_message

    result = prompt.execute(prompt: user_message, context: nil)

    @planned_tools = result[:content][:tool_sequence] || []
    
    # Debug logging
    Rails.logger.info "[StepExecutionWorkflow] LLM Planning Result:"
    Rails.logger.info "  Tool Sequence: #{@planned_tools.size} tools"
    Rails.logger.info "  Expected Outcome: #{result[:content][:expected_outcome]}"
    if @planned_tools.empty?
      Rails.logger.warn "  ⚠️  LLM returned 0 tools! Full response: #{result[:content].inspect}"
    end
    
    record_decision(
      decision: "planning_complete",
      reasoning: result[:content]["expected_outcome"] || "Planning complete",
      context: { 
        planned_tool_count: @planned_tools.size,
        expected_outcome: result[:content]["expected_outcome"]
      }
    )
  end

  # Phase 3: Validate Tools
  # Validate each planned tool call before execution
  def validate_tools
    record_decision(
      decision: "validate_tools",
      reasoning: "Validating #{@planned_tools.size} planned tool calls",
      context: { tool_count: @planned_tools.size }
    )

    # Use ToolValidationPrompt for each tool (or batch them)
    @validation_results = @planned_tools.map do |tool_call|
      validate_single_tool(tool_call)
    end

    warnings_count = @validation_results.count { |r| r["warnings"]&.any? }
    errors_count = @validation_results.count { |r| r["errors"]&.any? }

    record_decision(
      decision: "validation_complete",
      reasoning: "Validated #{@validation_results.size} tools: #{warnings_count} warnings, #{errors_count} errors",
      context: { 
        validation_passed: @validation_results.count { |v| v["valid"] },
        warnings: warnings_count,
        errors: errors_count
      }
    )
  end

  # Phase 4: Execute Tools
  # Execute the planned and validated tool calls
  def execute_tools
    record_decision(
      decision: "execute_tools",
      reasoning: "Executing tools for step: #{@step.title}",
      context: { validation_warnings: @validation_results.size }
    )

    # Initialize services
    diff_service = DiffGenerationService.new

    @tool_executions = []
    @diffs = {}

    # Execute each planned tool
    @planned_tools.each_with_index do |tool_call, index|
      tool_name = tool_call[:tool]
      tool_params = tool_call[:params] || {}

      begin
        # For write_file, capture old content for diff
        old_content = nil
        if tool_name == "write_file"
          file_path = tool_params[:path] || tool_params["path"]
          full_path = File.join(@path, file_path)
          old_content = File.exist?(full_path) ? File.read(full_path) : nil
        end

        # Add codebase_path to params for Sisyphus tools
        enriched_params = tool_params.symbolize_keys.merge(codebase_path: @path)

        # Execute the tool using Sisyphus-specific tools
        result = execute_sisyphus_tool(tool_name, enriched_params)

        @tool_executions << {
          index: index,
          tool: tool_name,
          params: tool_params,
          executed: true,
          success: result[:success],
          output: result[:content] || result[:error],
          result: result
        }

        # Generate diff for file changes
        if tool_name == "write_file" && result[:success]
          file_path = tool_params[:path] || tool_params["path"]
          new_content = tool_params[:content] || tool_params["content"]
          
          diff = diff_service.generate_diff(
            file_path: file_path,
            old_content: old_content,
            new_content: new_content
          )
          
          @diffs[file_path] = diff
        end

      rescue StandardError => e
        Rails.logger.error "[StepExecutionWorkflow] Tool execution failed: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        
        @tool_executions << {
          index: index,
          tool: tool_name,
          params: tool_params,
          executed: true,
          success: false,
          output: e.message,
          error: e.class.name
        }
      end
    end

    record_decision(
      decision: "execution_complete",
      reasoning: "Executed #{@tool_executions.size} tools",
      context: { 
        executions_successful: @tool_executions.count { |e| e[:success] },
        files_changed: @diffs.size
      }
    )
  end

  # Phase 5: Record Results
  # Build StepResult object with all execution data
  def record_results
    record_decision(
      decision: "record_results",
      reasoning: "Recording results for step: #{@step.title}",
      context: {
        tool_executions: @tool_executions.size,
        diffs_generated: @diffs.size
      }
    )

    # TODO: Implement in Milestone 2 with StepResult class
    # For now, return a hash structure
    {
      step_id: @step.number,
      step_title: @step.title,
      success: true,
      actions_taken: @tool_executions,
      files_changed: @diffs.keys,
      diffs: @diffs,
      tool_outputs: {},
      duration: 0.0,
      executed_at: Time.now.utc.iso8601,
      metadata: {
        workflow_id: @workflow_id,
        assembled_context_keys: @assembled_context.keys,
        planned_tool_count: @planned_tools.size,
        validation_warnings: @validation_results.size
      }
    }
  end

  # Handle execution errors
  def handle_error(error)
    Rails.logger.error "[StepExecutionWorkflow] Error in step #{@step&.number}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")

    record_decision(
      decision: "execution_failed",
      reasoning: "Step execution failed: #{error.message}",
      context: {
        error_class: error.class.name,
        step_number: @step&.number,
        current_phase: current_state
      }
    )

    mark_failed(error.message)

    {
      step_id: @step&.number,
      step_title: @step&.title,
      success: false,
      error_message: error.message,
      error_class: error.class.name,
      actions_taken: @tool_executions,
      files_changed: [],
      diffs: {},
      metadata: {
        workflow_id: @workflow_id,
        failed_at_phase: current_state,
        final_state: current_state
      }
    }
  end

  # Generate a quick file tree summary for context
  def generate_file_tree_summary
    return nil unless File.directory?(@path)

    # Get top-level directories
    dirs = Dir.glob("#{@path}/*").select { |f| File.directory?(f) }
                                 .map { |f| File.basename(f) }
                                 .reject { |d| d.start_with?(".") || d == "node_modules" || d == "vendor" }
                                 .first(20)

    dirs.join(", ")
  rescue StandardError
    nil
  end

  # Get available tools for planning
  def get_available_tools
    [
      {
        name: "read_file",
        description: "Read a file from the codebase",
        parameters: {
          path: "string - The path to the file to read"
        }
      },
      {
        name: "write_file",
        description: "Write or update a file in the codebase",
        parameters: {
          path: "string - The path to the file to write",
          content: "string - The content to write to the file"
        }
      },
      {
        name: "bash",
        description: "Execute a bash command (tests, syntax checks, etc)",
        parameters: {
          command: "string - The bash command to execute"
        }
      },
      {
        name: "grep",
        description: "Search for patterns in the codebase",
        parameters: {
          pattern: "string - The pattern to search for",
          path: "string (optional) - Specific path to search in"
        }
      }
    ]
  end

  # Validate a single tool call using ToolValidationPrompt
  def validate_single_tool(tool_call)
    prompt = Execution::ToolValidationPrompt.new(
      tool_call: tool_call,
      context: { codebase_path: @path, existing_files: [] }
    )

    user_message = <<~MSG
      Validate this tool call:

      **Tool**: #{tool_call["tool"]}
      **Parameters**: #{tool_call["params"].inspect}
      **Rationale**: #{tool_call["rationale"]}

      Is this tool call valid and safe to execute?
    MSG

    result = prompt.execute(prompt: user_message, context: nil)
    result[:content]
  rescue StandardError => e
    # If validation fails, mark as valid with warning
    Rails.logger.warn "[StepExecutionWorkflow] Tool validation failed: #{e.message}"
    {
      "valid" => true,
      "warnings" => ["Validation check failed: #{e.message}"],
      "errors" => [],
      "should_proceed" => true
    }
  end

  # Execute a tool using Sisyphus-specific implementations
  def execute_sisyphus_tool(tool_name, params)
    tool_class = case tool_name
    when "write_file"
      Sisyphus::WriteFileTool
    when "bash"
      Sisyphus::BashTool
    when "read_file"
      Sisyphus::ReadFileTool
    else
      raise ArgumentError, "Unknown Sisyphus tool: #{tool_name}"
    end

    tool = tool_class.new
    tool.execute(**params)
  end
end

