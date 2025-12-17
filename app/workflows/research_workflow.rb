# frozen_string_literal: true

# Main workflow that orchestrates the full research process.
# Uses GoalDecompositionWorkflow for recursive goal breakdown,
# then investigates each leaf goal with parallel analysis passes.
#
# This workflow maintains its own WorkflowMemoryStore and can query
# the parent worker's memory for context.
class ResearchWorkflow < BaseWorkflow
  attr_reader :goal, :research_path, :research_memory, :context

  # Number of parallel analysis passes for cross-validation
  PARALLEL_PASSES = 3

  # Research-specific states (override base workflow)
  initial_state :pending

  state :pending,      phase: nil,        description: "Workflow created"
  state :running,      phase: :setup,     description: "Initializing"
  state :decomposing,  phase: :planning,  description: "Breaking down goal"
  state :discovering,  phase: :research,  description: "Finding files"
  state :analyzing,    phase: :research,  description: "Analyzing code"
  state :synthesizing, phase: :output,    description: "Synthesizing findings"
  state :complete,     phase: nil,        description: "Completed"
  state :failed,       phase: nil,        description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :decomposing, on: :initialized
  transition from: :decomposing, to: :discovering, on: :decomposed
  transition from: :discovering, to: :analyzing, on: :files_found
  transition from: :analyzing, to: :synthesizing, on: :analyzed
  transition from: :synthesizing, to: :complete, on: :finish
  transition from: [:running, :decomposing, :discovering, :analyzing, :synthesizing],
             to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # @param goal [String] The research goal/topic
  # @param owner_id [String] Unique ID for state isolation
  # @param research_path [String] Path to the codebase
  # @param context [Hash] Seed context for research planning
  # @param parent_memory [#get_section, nil] Parent worker's memory for context queries
  # @param max_depth [Integer] Maximum goal decomposition depth
  def initialize(goal:, owner_id:, research_path:, context: {}, parent_memory: nil, max_depth: 4)
    super(owner_id: owner_id, parent_memory: parent_memory)
    @goal = goal
    @research_path = research_path
    @context = context || {}
    @max_depth = max_depth
    @research_memory = nil
    @goal_tree = nil
    @all_findings = []
  end

  # Setup for compatibility with BaseWorkflow
  def setup(prompt: nil, conversation: nil, sandbox_path: nil)
    @research_path ||= sandbox_path
    super
    self
  end

  # Execute the full research workflow
  def execute
    trigger(:start)
    initialize_memory
    record_decision(
      decision: "Starting research workflow",
      rationale: "Goal: #{goal}",
      context: { max_depth: @max_depth, seed_context: context.keys }
    )

    # Phase 1: Decompose
    trigger(:initialized)
    decompose_goal

    # Phase 2 & 3: Discover and Analyze for each leaf
    trigger(:decomposed)
    investigate_leaves

    trigger(:files_found)
    # Analysis happens in investigate_leaves

    # Phase 4: Synthesize
    trigger(:analyzed)
    synthesis_result = synthesize_findings

    mark_complete({
      goal: goal,
      goal_tree: @goal_tree,
      findings: @all_findings,
      synthesis: synthesis_result,
      memory_summary: @research_memory.summarize_findings,
      workflow_memory_summary: memory_summary
    })

    result
  rescue StandardError => e
    mark_failed(e.message)
    nil
  end

  private

  def initialize_memory
    store_path = File.join(
      ENV["AGENT_STATE_PATH"] || File.join(research_path, ".agents", "state"),
      owner_id,
      "research_memory.json"
    )
    @research_memory = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)
    @research_memory.set_section(:research_goal, [
      { text: goal, status: "active", context: context, timestamp: Time.now.utc.iso8601 }
    ])

    # Store any known files from context
    if context[:known_files]&.any?
      context[:known_files].each do |file_path|
        Memories::Research::DiscoveredFilesMemory.add_file(
          store: @research_memory,
          path: file_path,
          relevance_score: 1.0,
          reasoning: "Provided in seed context"
        )
      end
    end

    # Store prior findings as initial context
    if context[:prior_findings].present?
      @research_memory.push_context(
        sub_question: "[Seed context]",
        key_insights: context[:prior_findings]
      )
    end
  end

  def decompose_goal
    # Build context for decomposition including seed information
    decomposition_context = build_decomposition_context

    # Query parent memory for additional context if available
    if parent_memory
      parent_context = query_parent_memory(:research_goal, :context_chain)
      decomposition_context.merge!(parent_research_context: parent_context) if parent_context.any?
    end

    decomposition = GoalDecompositionWorkflow.new(
      goal: goal,
      owner_id: owner_id,
      context: decomposition_context,
      parent_memory: @research_memory, # Child workflow can query our memory
      max_depth: @max_depth
    )
    decomposition.setup(sandbox_path: research_path)
    decomposition.execute

    if decomposition.complete?
      @goal_tree = decomposition.result[:goal_tree]

      # Store sub-questions in memory
      decomposition.leaf_goals.each do |leaf|
        Memories::Research::SubQuestionsMemory.add_question(
          store: @research_memory,
          question: leaf[:text],
          is_leaf: true,
          priority: leaf[:priority] || 1,
          rationale: leaf[:rationale]
        )
      end
    else
      raise "Goal decomposition failed: #{decomposition.error}"
    end
  end

  def build_decomposition_context
    decomp_context = {}

    # Include codebase summary if provided
    decomp_context[:codebase_summary] = context[:codebase_summary] if context[:codebase_summary]

    # Include focus areas to guide decomposition
    if context[:focus_areas]&.any?
      decomp_context[:focus_areas] = context[:focus_areas]
    end

    # Include known files to inform decomposition
    if context[:known_files]&.any?
      decomp_context[:known_files] = context[:known_files]
    end

    # Include prior findings
    if context[:prior_findings].present?
      decomp_context[:prior_findings] = context[:prior_findings]
    end

    # Include any constraints
    if context[:constraints].present?
      decomp_context[:constraints] = context[:constraints]
    end

    decomp_context
  end

  def investigate_leaves
    leaves = collect_leaves(@goal_tree)

    leaves.each_with_index do |leaf, idx|
      @research_memory.next_iteration!

      # Discover relevant files
      discovered = discover_files(leaf[:text])

      # Analyze with parallel passes
      findings = analyze_with_passes(leaf[:text], discovered)
      @all_findings.concat(findings)

      # Chain context for next iteration
      @research_memory.push_context(
        sub_question: leaf[:text],
        key_insights: findings.first(3).map { |f| f[:text] }.join("; ")
      )
    end
  end

  def discover_files(question)
    discovered = []

    # Use FileTreeTool to get structure
    file_tree = FileTreeTool.new(sandbox_path: research_path)
    tree_result = file_tree.execute(path: research_path, extensions: ["rb", "py", "js", "ts"])

    if tree_result[:success]
      # Use GrepTool to find relevant files
      # Extract key terms from the question
      terms = extract_key_terms(question)

      terms.each do |term|
        grep = GrepTool.new(sandbox_path: research_path)
        grep_result = grep.execute(
          pattern: term,
          path: research_path,
          max_results: 20,
          case_insensitive: true
        )

        if grep_result[:success]
          grep_result[:result][:matches].each do |match|
            discovered << {
              path: match[:file],
              term: term,
              line: match[:line_number]
            }
          end
        end
      end
    end

    # Deduplicate and score relevance
    score_and_prioritize(discovered.uniq { |d| d[:path] }, question)
  end

  def score_and_prioritize(files, question)
    return [] if files.empty?

    # Use FileRelevancePrompt to score files
    prompt = Research::FileRelevancePrompt.new

    files_with_previews = files.first(20).map do |file|
      preview = File.read(file[:path], 2000) rescue "(unable to read)"
      { path: file[:path], preview: preview }
    end

    result = prompt.score_files(files: files_with_previews, question: question)

    evaluations = result[:content]["evaluations"] || []
    evaluations
      .select { |e| e["relevance_score"] >= 0.3 }
      .sort_by { |e| -e["relevance_score"] }
      .each do |eval|
        Memories::Research::DiscoveredFilesMemory.add_file(
          store: @research_memory,
          path: eval["file_path"],
          relevance_score: eval["relevance_score"],
          reasoning: eval["reasoning"]
        )
      end

    evaluations.select { |e| e["relevance_score"] >= 0.5 }
  end

  def analyze_with_passes(question, discovered_files)
    return [] if discovered_files.empty?

    findings = []
    prompt = Research::CodeUnderstandingPrompt.new

    # Run PARALLEL_PASSES independent analyses
    PARALLEL_PASSES.times do |pass_num|
      pass_findings = []

      discovered_files.first(5).each do |file_eval|
        file_path = file_eval["file_path"]
        next unless File.exist?(file_path)

        content = File.read(file_path) rescue next

        result = prompt.analyze(
          content: content,
          goal: question,
          file_path: file_path,
          previous_context: pass_num > 0 ? { key_findings: pass_findings.map { |f| f[:text] } } : nil
        )

        if result[:content]
          result[:content]["insights"]&.each do |insight|
            finding = {
              id: SecureRandom.uuid,
              text: insight["finding"],
              relevance: insight["relevance"],
              confidence: insight["confidence"],
              file_path: file_path,
              pass_number: pass_num + 1
            }
            pass_findings << finding

            Memories::Research::FindingsMemory.add_finding(
              store: @research_memory,
              text: insight["finding"],
              sub_question_id: question,
              file_path: file_path,
              confidence: insight["confidence"],
              pass_number: pass_num + 1
            )
          end
        end
      end

      findings.concat(pass_findings)
    end

    findings
  end

  def synthesize_findings
    # Group findings by pass for cross-validation
    findings_by_pass = @all_findings.group_by { |f| f[:pass_number] }

    prompt = Research::SynthesisPrompt.new
    sub_questions = collect_leaves(@goal_tree).map { |l| { text: l[:text] } }

    result = prompt.synthesize(
      findings: findings_by_pass.values.map { |pass| { insights: pass } },
      goal: goal,
      sub_questions: sub_questions
    )

    result[:content]
  end

  def collect_leaves(node, leaves = [])
    return leaves if node.nil?

    if node[:is_leaf]
      leaves << node
    else
      (node[:children] || []).each { |child| collect_leaves(child, leaves) }
    end

    leaves
  end

  def extract_key_terms(question)
    # Simple term extraction - extract significant words
    stop_words = %w[the a an is are was were what how why when where which who whom whose if then else do does did has have had been being be this that these those it its]

    question
      .downcase
      .gsub(/[^a-z0-9\s]/, "")
      .split
      .reject { |w| stop_words.include?(w) || w.length < 3 }
      .uniq
      .first(5)
  end
end

