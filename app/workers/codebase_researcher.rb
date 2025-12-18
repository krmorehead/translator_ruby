# frozen_string_literal: true

# Worker that orchestrates codebase research.
# Given a goal (research topic) and path (codebase root), it decomposes
# the topic into sub-questions, discovers relevant files, analyzes code,
# and synthesizes findings into structured documentation.
#
# State Flow:
#   pending -> initializing -> decomposing -> discovering -> analyzing -> synthesizing -> complete
#   Any active state can transition to failed via :error event
#   Failed state can retry back to pending
#
# @example Basic usage
#   worker = CodebaseResearcher.new(
#     goal: "How does authentication work?",
#     path: "/path/to/codebase"
#   )
#   result = worker.execute
#
# @example With seed context from another worker
#   worker = CodebaseResearcher.new(
#     goal: "How does the payment flow work?",
#     path: "/path/to/codebase",
#     context: {
#       known_files: ["app/services/payment_service.rb"],
#       prior_findings: "Payment uses Stripe API",
#       focus_areas: ["error handling", "refund logic"]
#     }
#   )
#
class CodebaseResearcher < BaseWorker
  attr_reader :memory_store

  # Override base worker states with research-specific state machine
  initial_state :pending

  # Research phases as states
  state :pending,      phase: nil,        description: "Worker created, not yet started"
  state :initializing, phase: :setup,     description: "Setting up memory store and context"
  state :decomposing,  phase: :planning,  description: "Breaking goal into sub-questions"
  state :discovering,  phase: :research,  description: "Finding relevant files"
  state :analyzing,    phase: :research,  description: "Analyzing code with parallel passes"
  state :synthesizing, phase: :output,    description: "Synthesizing findings into documentation"
  state :complete,     phase: nil,        description: "Research completed successfully"
  state :failed,       phase: nil,        description: "Research encountered an error"

  # Define valid transitions
  transition from: :pending,      to: :initializing, on: :start
  transition from: :initializing, to: :decomposing,  on: :initialized
  transition from: :decomposing,  to: :discovering,  on: :decomposed
  transition from: :discovering,  to: :analyzing,    on: :files_found
  transition from: :analyzing,    to: :synthesizing, on: :analyzed
  transition from: :synthesizing, to: :complete,     on: :synthesized

  # Error transition from any active state
  transition from: [:initializing, :decomposing, :discovering, :analyzing, :synthesizing],
             to: :failed, on: :error

  # Retry from failed state
  transition from: :failed, to: :pending, on: :retry

  # Register the research workflow
  register_workflow ResearchWorkflow

  # Initialize the codebase researcher
  # @param goal [String] The research topic/objective
  # @param path [String] The codebase root path to research
  # @param context [Hash] Optional seed context for research planning
  #   - known_files [Array<String>] Files already known to be relevant
  #   - prior_findings [String] Previous research findings to build on
  #   - focus_areas [Array<String>] Specific areas to prioritize
  #   - codebase_summary [String] High-level codebase description
  #   - constraints [Hash] Any constraints on the research
  # @param options [Hash] Additional options
  #   - max_depth [Integer] Maximum decomposition depth (default: 4)
  #   - output_modes [Array<Symbol>] Output modes to generate (default: [:report, :documentation])
  def initialize(goal:, path:, context: {}, **options)
    super
    @max_depth = options.fetch(:max_depth, 4)
    @output_modes = Array(options.fetch(:output_modes, [:report, :documentation])).map(&:to_sym)
    @memory_store = nil
    @findings = []
    @file_analyses = []
    @sub_questions = []
    @relevant_files = []
    @relevant_files_tree = ""
    @synthesis = nil
    @started_at = nil
  end

  # Execute the research workflow
  # @return [Hash] Research results with findings, output files, and metadata
  def execute
    @started_at = Time.now.utc

    # Start the state machine
    trigger(:start)
    initialize_research

    trigger(:initialized)
    decompose_goal

    trigger(:decomposed)
    discover_files

    trigger(:files_found)
    analyze_code

    trigger(:analyzed)
    synthesize_findings

    trigger(:synthesized)
    compile_results
  rescue StandardError => e
    handle_error(e)
  end

  # Get the current research phase
  # @return [Symbol, nil] The current phase (:setup, :planning, :research, :output, or nil)
  def phase
    current_phase
  end

  private

  def initialize_research
    ensure_state_directory!
    @memory_store = create_memory_store
    @memory_store.set_section(:research_goal, [
      { text: goal, status: "active", timestamp: Time.now.utc.iso8601 }
    ])
  end

  def decompose_goal
    # This is handled by the ResearchWorkflow
    # State tracking happens here, actual work in workflow
  end

  def discover_files
    # This is handled by the ResearchWorkflow
  end

  def analyze_code
    # This is handled by the ResearchWorkflow
  end

  def synthesize_findings
    execute_research_workflow
  end

  def create_memory_store
    store_path = File.join(state_path, "research_memory.json")
    ResearchMemoryStore.new(path: store_path, owner_id: owner_id)
  end

  def execute_research_workflow
    workflow = ResearchWorkflow.new(
      goal: goal,
      owner_id: owner_id,
      research_path: path,
      context: context,
      parent_memory: @memory_store, # Pass our memory so workflow can query it
      max_depth: @max_depth,
      output_modes: @output_modes
    )
    workflow.setup(sandbox_path: path)
    workflow.execute

    if workflow.complete?
      store_workflow_result("research_workflow", workflow.result)
      @findings = workflow.result[:findings] || []
      @file_analyses = workflow.result[:file_analyses] || []
      @sub_questions = workflow.result[:sub_questions] || []
      @relevant_files = workflow.result[:relevant_files] || []
      @relevant_files_tree = workflow.result[:relevant_files_tree] || ""
      @synthesis = workflow.result[:synthesis]
      @memory_store = workflow.research_memory

      # Also record state transitions from workflow
      if workflow.workflow_memory&.state_history&.any?
        workflow.workflow_memory.state_history.each do |transition|
          @memory_store.record_state_transition(
            from: transition[:from],
            to: transition[:to],
            event: transition[:event],
            source: "research_workflow",
            payload: transition[:payload] || {}
          )
        end
      end
    elsif workflow.failed?
      raise "Research workflow failed: #{workflow.error}"
    end
  end

  def compile_results
    @result = {
      success: true,
      goal: goal,
      path: path,
      owner_id: owner_id,
      findings: @findings,
      file_analyses: @file_analyses,
      sub_questions: @sub_questions,
      relevant_files: @relevant_files,
      relevant_files_tree: @relevant_files_tree,
      synthesis: @synthesis,
      output_modes: @output_modes,
      memory: @memory_store.to_h,
      output_files: [],
      state_history: state_history,
      metadata: {
        max_depth: @max_depth,
        output_modes: @output_modes,
        context: context,
        started_at: @started_at&.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state
      }
    }
    @result
  end

  def handle_error(error)
    @error = error.message
    trigger(:error) if can_trigger?(:error)

    {
      success: false,
      error: error.message,
      findings: @findings,
      synthesis: @synthesis,
      goal: goal,
      path: path,
      owner_id: owner_id,
      memory: @memory_store&.to_h || {},
      output_files: [],
      state_history: state_history,
      metadata: {
        max_depth: @max_depth,
        context: context,
        started_at: @started_at&.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state,
        error_state: current_state
      }
    }
  end
end
