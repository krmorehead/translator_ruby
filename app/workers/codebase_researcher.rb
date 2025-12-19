# frozen_string_literal: true

# Goal-driven agent for codebase research.
# Given a goal (research topic) and path (codebase root), the agent
# dynamically plans and executes actions to discover, analyze, and
# synthesize information from the codebase.
#
# The agent uses an LLM planner to select from available actions or
# compose custom workflows based on the current state and goal progress.
#
# @example Basic usage
#   researcher = CodebaseResearcher.new(
#     goal: "How does authentication work?",
#     path: "/path/to/codebase"
#   )
#   result = researcher.execute
#
# @example With seed context
#   researcher = CodebaseResearcher.new(
#     goal: "How does the payment flow work?",
#     path: "/path/to/codebase",
#     context: {
#       known_files: ["app/services/payment_service.rb"],
#       prior_findings: "Payment uses Stripe API",
#       focus_areas: ["error handling", "refund logic"]
#     }
#   )
#
class CodebaseResearcher < AgentWorker
  include ActionRegistry

  # Register research-specific actions
  register_action :search_files,
    class_name: "Actions::SearchFilesAction",
    description: "Search for files by filename pattern or content",
    category: :discovery,
    parameters: {
      pattern: { type: :string, required: true, description: "Search pattern" },
      search_type: { type: :string, required: false, description: "'filename' or 'content'" },
      file_types: { type: :array, required: false, description: "File extensions to include" }
    }

  register_action :locate_definition,
    class_name: "Actions::LocateDefinitionAction",
    description: "Find where a class, module, method, or constant is defined",
    category: :discovery,
    parameters: {
      symbol: { type: :string, required: true, description: "Symbol name to locate" },
      type: { type: :string, required: false, description: "'class', 'module', 'method', 'constant', or 'any'" }
    }

  register_action :analyze_file,
    class_name: "Actions::AnalyzeFileAction",
    description: "Analyze a file's contents for information relevant to the goal",
    category: :analysis,
    parameters: {
      file_path: { type: :string, required: true, description: "Path to the file to analyze" },
      focus: { type: :string, required: false, description: "Specific aspect to focus on" },
      questions: { type: :array, required: false, description: "Specific questions to answer" }
    }

  register_action :trace_references,
    class_name: "Actions::TraceReferencesAction",
    description: "Find where a symbol is used throughout the codebase",
    category: :discovery,
    parameters: {
      symbol: { type: :string, required: true, description: "Symbol to trace" },
      exclude_definitions: { type: :boolean, required: false, description: "Exclude definition sites" }
    }

  register_action :decompose_question,
    class_name: "Actions::DecomposeQuestionAction",
    description: "Break down a complex question into smaller sub-questions",
    category: :planning,
    parameters: {
      question: { type: :string, required: true, description: "Question to decompose" },
      max_questions: { type: :integer, required: false, description: "Maximum sub-questions" }
    }

  register_action :synthesize_partial,
    class_name: "Actions::SynthesizePartialAction",
    description: "Synthesize current findings into a partial summary",
    category: :synthesis,
    parameters: {
      focus: { type: :string, required: false, description: "Focus area for synthesis" },
      include_unknowns: { type: :boolean, required: false, description: "Include unknown aspects" }
    }

  attr_reader :output_modes

  # Get the current research phase
  # @return [Symbol, nil] The current phase (:setup, :reasoning, :work, :output, or nil)
  def phase
    current_phase
  end

  def initialize(goal:, path:, context: {}, **options)
    super
    @output_modes = Array(options.fetch(:output_modes, [:report, :documentation])).map(&:to_sym)
    @max_depth = options.fetch(:max_depth, 4)
    @file_analyses = []
    @sub_questions = []
    @relevant_files = []
  end

  protected

  # Create the research memory store
  # @return [ResearchMemoryStore] The memory store
  def create_memory_store
    store_path = File.join(state_path, "research_memory.json")
    store = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)

    # Set the research goal
    store.set_section(:research_goal, [
      { text: goal, status: "active", context: context, timestamp: Time.now.utc.iso8601 }
    ])

    store
  end

  # Override goal evaluation with research-specific logic
  # @return [Boolean] True if goal is achieved
  def goal_achieved?
    # Need at least some findings
    findings = memory_store.get_section(:findings)
    return false if findings.empty?

    # Check via goal progress prompt
    progress = evaluate_goal_progress

    # Consider achieved if confidence is high enough
    progress[:goal_achieved] == true ||
      (progress[:confidence] && progress[:confidence] >= 0.8 && progress[:recommendation] == "synthesize")
  end

  # Build context optimized for research planning
  # @return [Contexts::ResearchContext] Planning context
  def build_planning_context
    research_context = Contexts::ResearchContext.new(research_goal: goal)

    # Add recent findings from memory
    findings = memory_store.get_section(:findings)
    findings.last(10).each do |finding|
      research_context.add_finding(
        finding: finding[:text],
        file_path: finding[:source],
        sub_question: finding[:sub_question],
        confidence: finding[:confidence] || 0.7
      )
    end

    # Add discovered files
    discovered = memory_store.get_section(:discovered_files)
    discovered.last(10).each do |file|
      research_context.add(
        content: "File: #{file[:path]} (#{file[:analyzed] ? 'analyzed' : 'discovered'})",
        topics: ["discovered_file"],
        source: "discovery",
        metadata: file
      )
    end

    # Add sub-questions
    sub_questions = memory_store.get_section(:sub_questions)
    sub_questions.each do |sq|
      research_context.add(
        content: "Sub-question (#{sq[:status] || 'pending'}): #{sq[:text]}",
        topics: ["sub_question", sq[:status] || "pending"],
        source: "planning"
      )
    end

    # Add action history summary from context
    research_context.add_sub_context(:actions, @action_history_context)

    research_context
  end

  # Build context for goal evaluation
  # @return [Contexts::ResearchContext] Evaluation context
  def build_evaluation_context
    research_context = Contexts::ResearchContext.new(research_goal: goal)

    research_context.add(content: "Goal: #{goal}", topics: ["goal"], source: "agent")
    research_context.add(content: "Iterations: #{@iteration_count}", topics: ["progress"], source: "agent")
    research_context.add(content: "Actions executed: #{@action_count}", topics: ["progress"], source: "agent")

    # Add all findings from memory
    findings = memory_store.get_section(:findings)
    findings.each do |finding|
      research_context.add_finding(
        finding: finding[:text],
        file_path: finding[:source],
        sub_question: finding[:sub_question],
        confidence: finding[:confidence] || 0.7
      )
    end

    # Add file coverage
    discovered = memory_store.get_section(:discovered_files)
    analyzed_count = discovered.count { |f| f[:analyzed] }
    research_context.add(
      content: "Files: #{discovered.size} discovered, #{analyzed_count} analyzed",
      topics: ["coverage"],
      source: "agent"
    )

    research_context
  end

  # Build result with research-specific metadata
  # @param synthesis [Hash] The synthesized findings
  # @return [Hash] Complete result
  def build_result(synthesis)
    # Collect relevant files from memory with full metadata
    discovered_files = memory_store.get_section(:discovered_files)
    relevant_files = discovered_files.map do |f|
      {
        file_path: f[:path],
        relevance_score: f[:relevance_score] || 0.5,
        analyzed: f[:analyzed] || false,
        reasoning: f[:reasoning]
      }
    end
    file_paths = relevant_files.map { |f| f[:file_path] }.compact

    super.merge(
      file_analyses: @file_analyses,
      sub_questions: memory_store.get_section(:sub_questions),
      relevant_files: relevant_files,
      relevant_files_tree: generate_files_tree(file_paths),
      output_modes: @output_modes,
      memory: memory_store.to_h,
      metadata: {
        iterations: @iteration_count,
        actions_executed: @action_count,
        max_depth: @max_depth,
        output_modes: @output_modes,
        context: context,
        started_at: @started_at.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state
      }
    )
  end

  private

  # Generate a tree representation of file paths
  # @param files [Array<String>] List of file paths
  # @return [String] Tree representation
  def generate_files_tree(files)
    return "" if files.empty?

    # Group by directory
    by_dir = files.group_by { |f| File.dirname(f) }

    lines = []
    by_dir.sort.each do |dir, dir_files|
      relative_dir = dir.sub("#{path}/", "")
      lines << relative_dir
      dir_files.each do |file|
        lines << "  └── #{File.basename(file)}"
      end
    end

    lines.join("\n")
  end
end
