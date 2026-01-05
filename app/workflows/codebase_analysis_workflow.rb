# frozen_string_literal: true

# Workflow that analyzes the codebase to understand context for plan generation.
# This performs lightweight, targeted analysis for planning context.
#
# Distinct from ResearchWorkflow which does deep, iterative exploration.
# CodebaseAnalysisWorkflow focuses on identifying files and patterns relevant
# to a specific planning goal.
class CodebaseAnalysisWorkflow < BaseWorkflow
  attr_reader :goal, :path, :max_files

  # Analysis-specific states
  initial_state :pending

  state :pending,     description: "Workflow created"
  state :running,     description: "Initializing"
  state :scanning,    description: "Scanning codebase structure"
  state :analyzing,   description: "Analyzing relevance"
  state :complete,    description: "Completed"
  state :failed,      description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :scanning, on: :initialized
  transition from: :scanning, to: :analyzing, on: :scanned
  transition from: :analyzing, to: :complete, on: :finish
  transition from: [:running, :scanning, :analyzing], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # Default maximum files to analyze
  DEFAULT_MAX_FILES = 15

  # @param goal [String] The goal to analyze the codebase for
  # @param path [String] Root directory path
  # @param owner_id [String] Unique ID for state isolation
  # @param parent_id [String] Parent workflow ID for graph linking
  # @param max_files [Integer] Maximum files to include in analysis
  def initialize(goal:, path:, owner_id:, parent_id:, max_files: DEFAULT_MAX_FILES)
    validate_parameters!(goal, path, owner_id)
    super(owner_id: owner_id, parent_id: parent_id)

    @goal = goal
    @path = path
    @max_files = max_files
    @file_tree = nil
    @analysis_results = {}
  end

  # Execute the analysis workflow
  # @return [Hash] Analysis results with relevant_files, patterns, constraints, context
  def execute
    trigger(:start)
    initialize_workflow_memory
    record_decision(
      decision: "Starting codebase analysis",
      rationale: "Goal: #{goal}",
      context: { path: path, max_files: max_files }
    )

    # Phase 1: Scan codebase structure
    trigger(:initialized)
    scan_codebase

    # Phase 2: Analyze with LLM
    trigger(:scanned)
    analyze_codebase

    # Complete
    mark_complete(@analysis_results)
    @analysis_results
  rescue => e
    mark_failed("Analysis failed: #{e.message}")
    # Return default structure even on failure
    {
      relevant_files: [],
      patterns: [],
      constraints: [],
      context: "Analysis failed: #{e.message}"
    }
  end

  private

  # Scan the codebase to get file tree
  def scan_codebase
    tool = FileTreeTool.new
    result = tool.execute(path: @path, max_depth: 5)

    if result[:success] && result[:output]
      @file_tree = result[:output]
      file_count = result[:output].is_a?(String) ? result[:output].lines.count : 0
      record_decision(
        decision: "Scanned codebase structure",
        rationale: "Generated file tree for analysis",
        context: { file_count: file_count }
      )
    else
      raise "Failed to scan codebase: #{result[:error] || 'No output generated'}"
    end
  end

  # Analyze codebase with LLM
  def analyze_codebase
    prompt = Planning::CodebaseAnalysisPrompt.new(
      goal: @goal,
      file_tree: @file_tree,
      path: @path
    )

    response = prompt.execute
    content = response[:content]

    @analysis_results = {
      relevant_files: Array(content[:relevant_files]).take(@max_files),
      patterns: Array(content[:patterns]),
      constraints: Array(content[:constraints]),
      context: content[:context]
    }

    record_decision(
      decision: "Completed codebase analysis",
      rationale: "Identified #{@analysis_results[:relevant_files].size} relevant files",
      context: {
        relevant_files_count: @analysis_results[:relevant_files].size,
        patterns_count: @analysis_results[:patterns].size,
        constraints_count: @analysis_results[:constraints].size
      }
    )
  end

  def validate_parameters!(goal, path, owner_id)
    raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
    raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
    raise ArgumentError, "owner_id must be a String, got #{owner_id.class}" unless owner_id.is_a?(String)
  end
end

