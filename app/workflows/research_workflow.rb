# frozen_string_literal: true

# Main workflow that orchestrates the full research process.
# Uses GoalDecompositionWorkflow for recursive goal breakdown,
# then investigates each leaf goal with parallel analysis passes.
#
# Key features:
# - Per-leaf synthesis: Each sub-question is synthesized immediately after investigation
# - File tracking: Prevents re-examining the same files across leaves
# - Early termination: Stops if consecutive leaves find no new files
# - Configurable output modes: Array of [:report, :documentation]
# - References can be reused/updated on future research passes
#
# This workflow maintains its own WorkflowMemoryStore and can query
# the parent worker's memory for context.
class ResearchWorkflow < BaseWorkflow
  # Use ResearchMemoryStore instead of WorkflowMemoryStore
  MEMORY_STORE = ResearchMemoryStore
  
  attr_reader :goal, :research_path, :context, :output_modes

  # Number of parallel analysis passes for cross-validation
  # Reduced to 1 for performance - single focused analysis is sufficient
  PARALLEL_PASSES = 1

  # Stop if this many consecutive leaves find no new files
  MAX_EMPTY_LEAVES = 3

  # Research-specific states (override base workflow)
  initial_state :pending

  state :pending,      phase: nil,        description: "Workflow created"
  state :running,      phase: :setup,     description: "Initializing"
  state :decomposing,  phase: :planning,  description: "Breaking down goal"
  state :discovering,  phase: :research,  description: "Finding files"
  state :analyzing,    phase: :research,  description: "Analyzing code"
  state :documenting,  phase: :research,  description: "Generating per-file docs"
  state :organizing,   phase: :output,    description: "Organizing documentation"
  state :synthesizing, phase: :output,    description: "Synthesizing findings"
  state :complete,     phase: nil,        description: "Completed"
  state :failed,       phase: nil,        description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :decomposing, on: :initialized
  transition from: :decomposing, to: :discovering, on: :decomposed
  transition from: :discovering, to: :documenting, on: :files_found
  transition from: :documenting, to: :analyzing, on: :documented
  transition from: :analyzing, to: :synthesizing, on: :analyzed
  transition from: :synthesizing, to: :complete, on: :finish
  transition from: [:running, :decomposing, :discovering, :documenting, :analyzing, :synthesizing],
             to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # Valid output modes
  VALID_OUTPUT_MODES = [:report, :documentation].freeze

  # @param goal [String] The research goal/topic
  # @param owner_id [String] Unique ID for state isolation
  # @param research_path [String] Path to the codebase
  # @param context [Hash] Seed context for research planning
  # @param parent_memory [#get_section, nil] Parent worker's memory for context queries
  # @param max_depth [Integer] Maximum goal decomposition depth
  # @param output_modes [Array<Symbol>] Output modes to generate (default: [:report, :documentation])
  def initialize(goal:, owner_id:, research_path:, parent_id:, context: {}, max_depth: 20, output_modes: [:report, :documentation])
    raise ArgumentError, "parent_id is required" if parent_id.nil? || parent_id.to_s.empty?
    
    @goal = goal
    @research_path = research_path
    @context = context || {}
    @max_depth = max_depth
    @output_modes = Array(output_modes).map(&:to_sym) & VALID_OUTPUT_MODES
    @output_modes = [:report] if @output_modes.empty? # Default fallback
    
    # Initialize base workflow (creates workflow_memory using MEMORY_STORE constant)
    super(owner_id: owner_id, parent_id: parent_id)
    
    # Initialize research-specific data structures
    @research_context = Contexts::ResearchContext.new(research_goal: goal)
    @goal_tree = nil
    @all_findings = []
    @leaf_syntheses = []
    @file_analyses = []
    @explored_files = Set.new
    @relevant_files = []  # Files that scored high relevance for the research goal
    @sub_questions = []
    
    # Set research-specific sections in memory
    workflow_memory.set_section(:research_goal, [
      { text: goal, status: "active", context: context, timestamp: Time.now.utc.iso8601 }
    ])
    
    # Store any known files from context
    if context[:known_files]&.any?
      context[:known_files].each do |file_path|
        Memories::Research::DiscoveredFilesMemory.add_file(
          store: workflow_memory,
          path: file_path,
          relevance_score: 1.0,
          reasoning: "Provided in seed context"
        )
      end
    end
    
    # Store prior findings as initial context
    if context[:prior_findings].present?
      workflow_memory.push_context(
        sub_question: "[Seed context]",
        key_insights: context[:prior_findings]
      )
    end
  end


  # Execute the full research workflow
  # Produces outputs based on output_modes array
  def execute
    trigger(:start)
    
    record_decision(
      decision: "Starting research workflow",
      rationale: "Goal: #{goal}, Output modes: #{output_modes.join(', ')}",
      context: { max_depth: @max_depth, output_modes: output_modes, seed_context: context.keys }
    )

    # Phase 1: Decompose goal into sub-questions
    trigger(:initialized)
    decompose_goal

    # Phase 2: Discover relevant files
    trigger(:decomposed)
    discover_all_relevant_files

    # Phase 3: Document each file (if :documentation mode requested)
    trigger(:files_found)
    document_files if output_modes.include?(:documentation)

    # Phase 4: Analyze with parallel passes (if :report mode requested)
    trigger(:documented)
    analyze_discovered_files if output_modes.include?(:report)

    # Phase 5: Synthesize findings into report
    trigger(:analyzed)
    synthesis_result = synthesize_findings
    memory_summary = workflow_memory.summarize_findings

    mark_complete({
      goal: goal,
      goal_tree: @goal_tree,
      findings: @all_findings,
      file_analyses: @file_analyses,
      synthesis: synthesis_result,
      sub_questions: @sub_questions,
      output_modes: output_modes,
      relevant_files: @relevant_files,
      relevant_files_tree: generate_relevant_files_tree,
      memory_summary: memory_summary,
      workflow_memory_summary: memory_summary
    })

    result
  rescue StandardError => e
    Rails.logger.error "[ResearchWorkflow] Execute failed: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace[0..10].join("\n")
    mark_failed(e.message)
    nil
  end

  # Discover all relevant files across all leaf questions
  def discover_all_relevant_files
    leaves = collect_leaves(@goal_tree)

    leaves.each do |leaf|
      workflow_memory.next_iteration!
      discovered = discover_files(leaf[:text])

      # Track which sub-questions each file answers
      discovered.each do |file_eval|
        file_path = file_eval[:file_path]
        @explored_files.add(file_path)
      end
    end

    record_decision(
      decision: "Discovered #{@explored_files.size} relevant files",
      rationale: "Files will be documented and analyzed",
      context: { file_count: @explored_files.size, sub_questions: @sub_questions.size }
    )
  end

  # Analyze discovered files in batches for performance
  # Files are analyzed in batches to reduce LLM calls
  def analyze_discovered_files
    files_to_analyze = @explored_files.select { |f| File.exist?(f) }
    return if files_to_analyze.empty?

    # Batch files to reduce LLM calls (max 10 files per batch for quality)
    files_to_analyze.each_slice(10) do |batch|
      analyze_file_batch(batch)
    end
  end

  # Analyze a batch of files together for efficiency
  # @param file_paths [Array<String>] Paths to the files to analyze
  def analyze_file_batch(file_paths)
    return if file_paths.empty?

    prompt = Research::CodeUnderstandingPrompt.new

    file_paths.each do |file_path|
      content = File.read(file_path) rescue next
      
      # Get relevant context for this file
      relevant_context = @research_context.format_for_analysis(goal)
      previous_context = relevant_context.present? ? { prior_context: relevant_context } : nil

      # Single focused analysis per file (PARALLEL_PASSES = 1)
      result = prompt.analyze(
        content: content,
        goal: goal,
        file_path: file_path,
        previous_context: previous_context
      )

      next unless result[:content]

      file_findings = []
      result[:content][:insights]&.each do |insight|
        finding = WorkflowMemories::Finding.new(
          text: insight[:finding],
          file_path: file_path,
          confidence: insight[:confidence],
          pass_number: 1,
          sub_question_id: goal,
          relevance: insight[:relevance]
        )
        file_findings << finding

        @all_findings << finding

        # Add to legacy memory store
        Memories::Research::FindingsMemory.add_finding(
          store: workflow_memory,
          text: finding.text,
          sub_question_id: goal,
          file_path: file_path,
          confidence: finding.confidence,
          pass_number: 1
        )

        # Add to research context for relevance-aware retrieval
        @research_context.add_finding(
          finding: finding.text,
          file_path: file_path,
          sub_question: goal,
          confidence: finding.confidence
        )
      end

      # Create leaf synthesis for this file
      if file_findings.any?
        leaf_synthesis = synthesize_leaf(File.basename(file_path), file_findings)
        @leaf_syntheses << leaf_synthesis
      end
    end
  end

  # Document files in batches for efficiency
  def document_files
    files_to_document = @explored_files.select { |f| File.exist?(f) }
    return if files_to_document.empty?

    # Process files in smaller batches (max 10 per batch)
    files_to_document.each_slice(10) do |batch|
      document_file_batch(batch)
    end

    record_decision(
      decision: "Documented #{@file_analyses.size} files",
      rationale: "Per-file documentation generated in batches",
      context: { documented_count: @file_analyses.size }
    )
  end

  # Document a batch of files for efficiency
  # @param file_paths [Array<String>] Paths to the files to document
  def document_file_batch(file_paths)
    return if file_paths.empty?

    prompt = Research::PerFileDocPrompt.new

    file_paths.each do |file_path|
      content = File.read(file_path) rescue next

      # Get relevant context for documenting this file
      relevant_context = @research_context.for_file(file_path, limit: 3)
      prior_context_str = relevant_context.any? ? relevant_context.map(&:content).join("\n") : nil

      result = prompt.analyze(
        content: content,
        file_path: file_path,
        goal_context: goal,
        sub_questions: @sub_questions,
        prior_context: prior_context_str
      )

      next unless result[:content]

      @file_analyses << result[:content]

      # Also create findings for synthesis
      summary = result[:content][:summary]
      @all_findings << {
        id: SecureRandom.uuid,
        text: summary,
        file_path: file_path,
        type: :file_summary
      }

      # Add file summary to research context
      methods = (result[:content][:methods] || []).map { |m| m[:name] || m["name"] }
      @research_context.add_file_summary(
        file_path: file_path,
        summary: summary,
        methods: methods
      )
    end
  end

  def decompose_goal
    # Build context for decomposition including seed information
    decomposition_context = build_decomposition_context

    # Find relevant context if available
    relevant_context = find_relevant_context(query_text: "research goal context chain")
    decomposition_context.merge!(parent_research_context: relevant_context) if relevant_context.any?

    decomposition = GoalDecompositionWorkflow.new(
      goal: goal,
      owner_id: owner_id,
      parent_id: @workflow_id,  # This workflow is the parent
      context: decomposition_context,
      max_depth: @max_depth
    )
    decomposition.setup
    decomposition.execute

    if decomposition.complete?
      @goal_tree = decomposition.result[:goal_tree]

      # Store sub-questions in memory and research context
      decomposition.leaf_goals.each do |leaf|
        Memories::Research::SubQuestionsMemory.add_question(
          store: workflow_memory,
          question: leaf[:text],
          is_leaf: true,
          priority: leaf[:priority] || 1,
          rationale: leaf[:rationale]
        )

        # Add to research context for relevance-aware retrieval
        @research_context.add_sub_question(
          question: leaf[:text],
          parent_question: goal,
          priority: leaf[:priority] || 1
        )
        @sub_questions << leaf[:text]
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
    consecutive_empty = 0

    leaves.each do |leaf|
      workflow_memory.next_iteration!

      # Discover relevant files (filters out already-explored files)
      discovered = discover_files(leaf[:text])

      if discovered.empty?
        consecutive_empty += 1
        record_empty_result(leaf)

        # Early termination if too many consecutive empty results
        if consecutive_empty >= MAX_EMPTY_LEAVES
          record_decision(
            decision: "Terminating early",
            rationale: "#{MAX_EMPTY_LEAVES} consecutive leaves found no new files",
            context: { last_leaf: leaf[:text] }
          )
          break
        end
        next
      end

      consecutive_empty = 0 # Reset on success

      # Analyze with parallel passes
      findings = analyze_with_passes(leaf[:text], discovered)
      @all_findings.concat(findings)

      # Synthesize THIS leaf's findings immediately (small, focused context)
      leaf_synthesis = synthesize_leaf(leaf[:text], findings)
      @leaf_syntheses << leaf_synthesis

      # Chain the summary (not raw findings) to next iteration
      workflow_memory.push_context(
        sub_question: leaf[:text],
        key_insights: leaf_synthesis[:summary] || findings.first(3).map { |f| f[:text] }.join("; ")
      )
    end
  end

  def record_empty_result(leaf)
    record_decision(
      decision: "No new files found",
      rationale: "Sub-question '#{leaf[:text]}' found no unexplored files",
      context: { sub_question: leaf[:text], explored_count: @explored_files.size }
    )

    # Record an empty synthesis for this leaf
    @leaf_syntheses << {
      sub_question: leaf[:text],
      summary: "No relevant files found for this sub-question.",
      key_findings: [],
      conflicts: [],
      confidence: 0.0,
      gaps: ["Could not find relevant code to investigate"]
    }
  end

  def synthesize_leaf(sub_question, findings)
    return empty_leaf_synthesis(sub_question) if findings.empty?

    prompt = Research::LeafSynthesisPrompt.new
    result = prompt.synthesize_leaf(
      sub_question: sub_question,
      findings: findings
    )

    synthesis = result[:content] || {}
    synthesis[:sub_question] = sub_question
    synthesis
  end

  def empty_leaf_synthesis(sub_question)
    {
      sub_question: sub_question,
      summary: "No findings generated for this sub-question.",
      key_findings: [],
      conflicts: [],
      confidence: 0.0,
      gaps: ["No analysis results available"]
    }
  end

  def discover_files(question)
    discovered = []

    # Use FileTreeTool to get structure
    file_tree = FileTreeTool.new
    tree_result = file_tree.execute(path: research_path, extensions: ["rb", "py", "js", "ts"])

    if tree_result[:success]
      # Use GrepTool to find relevant files
      # Extract key terms from the question
      terms = extract_key_terms(question)

      terms.each do |term|
        grep = GrepTool.new
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

    # Deduplicate by path
    unique_discovered = discovered.uniq { |d| d[:path] }

    # Filter out already-explored files
    new_files = unique_discovered.reject { |f| @explored_files.include?(f[:path]) }

    # Score and prioritize the new files
    scored_files = score_and_prioritize(new_files, question)

    # Track newly discovered files that pass relevance threshold
    scored_files.each { |f| @explored_files.add(f[:file_path]) }

    scored_files
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

    evaluations = result[:content][:evaluations] || []
    evaluations
      .select { |e| e[:relevance_score] >= 0.3 }
      .sort_by { |e| -e[:relevance_score] }
      .each do |eval|
        Memories::Research::DiscoveredFilesMemory.add_file(
          store: workflow_memory,
          path: eval[:file_path],
          relevance_score: eval[:relevance_score],
          reasoning: eval[:reasoning]
        )
      end

    # Track files with high relevance (>= 0.5) as relevant to the research goal
    relevant = evaluations.select { |e| e[:relevance_score] >= 0.5 }
    relevant.each do |eval|
      @relevant_files << {
        file_path: eval[:file_path],
        relevance_score: eval[:relevance_score],
        reasoning: eval[:reasoning],
        sub_question: question
      }
    end

    relevant
  end

  def analyze_with_passes(question, discovered_files)
    return [] if discovered_files.empty?

    findings = []
    prompt = Research::CodeUnderstandingPrompt.new

    # Run PARALLEL_PASSES independent analyses
    PARALLEL_PASSES.times do |pass_num|
      pass_findings = []

      # Analyze only 3 files per leaf (reduced from 5) to control LLM context
      discovered_files.first(3).each do |file_eval|
        file_path = file_eval[:file_path]
        next unless File.exist?(file_path)

        content = File.read(file_path) rescue next

        # Only pass very limited context from first pass (prevent exponential growth)
        prior_context = if pass_num > 0 && pass_findings.any?
          {
            key_findings: pass_findings.first(3).map(&:text) # Limit to 3 most recent
          }
        else
          nil
        end

        result = prompt.analyze(
          content: content,
          goal: question,
          file_path: file_path,
          previous_context: prior_context
        )

        if result[:content]
          result[:content][:insights]&.each do |insight|
            finding = WorkflowMemories::Finding.new(
              text: insight[:finding],
              file_path: file_path,
              confidence: insight[:confidence],
              pass_number: pass_num + 1,
              sub_question_id: question,
              relevance: insight[:relevance]
            )
            pass_findings << finding

            Memories::Research::FindingsMemory.add_finding(
              store: workflow_memory,
              text: finding.text,
              sub_question_id: question,
              file_path: file_path,
              confidence: finding.confidence,
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
    # If we have no leaf syntheses, return early with empty result
    if @leaf_syntheses.empty?
      return {
        "summary" => "No findings were generated during research.",
        "validated_insights" => [],
        "conflicts" => [],
        "open_questions" => ["No relevant files found for: #{goal}"]
      }
    end

    # Combine the pre-synthesized leaf summaries (much smaller context than raw findings)
    prompt = Research::SynthesisPrompt.new
    result = prompt.combine_leaf_syntheses(
      goal: goal,
      leaf_syntheses: @leaf_syntheses
    )

    # Add detailed_sections from leaf syntheses for output formatting
    content = result[:content] || {}
    content[:detailed_sections] = @leaf_syntheses.map do |leaf|
      {
        sub_question: leaf[:sub_question] || leaf["sub_question"],
        answer: leaf[:summary] || leaf["summary"] || "",
        key_findings: (leaf[:key_findings] || leaf["key_findings"] || []).map { |f| f.is_a?(Hash) ? f[:finding] : f.to_s },
        confidence: leaf[:confidence] || leaf["confidence"] || 0.5
      }
    end
    content
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

  # Generate a tree representation of relevant files
  # @return [String] ASCII tree of relevant file paths
  def generate_relevant_files_tree
    return "" if @relevant_files.empty?

    # Get unique file paths and make them relative to research_path
    file_paths = @relevant_files
      .map { |f| f[:file_path] }
      .uniq
      .map { |p| Pathname.new(p).relative_path_from(Pathname.new(research_path)).to_s rescue p }
      .sort

    build_tree_string(file_paths)
  end

  # Build an ASCII tree string from a list of file paths
  def build_tree_string(paths)
    tree = {}

    # Build nested hash structure
    paths.each do |path|
      parts = path.split("/")
      current = tree
      parts.each_with_index do |part, idx|
        is_file = idx == parts.length - 1
        current[part] ||= is_file ? :file : {}
        current = current[part] unless is_file
      end
    end

    # Render tree to string
    lines = []
    render_tree_node(tree, "", lines, true)
    lines.join("\n")
  end

  def render_tree_node(node, prefix, lines, is_root)
    return unless node.is_a?(Hash)

    entries = node.keys.sort_by { |k| [node[k] == :file ? 1 : 0, k] }

    entries.each_with_index do |key, idx|
      is_last = idx == entries.size - 1
      connector = is_root ? "" : (is_last ? "└── " : "├── ")
      child_prefix = is_root ? "" : (is_last ? "    " : "│   ")

      value = node[key]
      if value == :file
        lines << "#{prefix}#{connector}#{key}"
      else
        lines << "#{prefix}#{connector}#{key}/"
        render_tree_node(value, prefix + child_prefix, lines, false)
      end
    end
  end
end

