# frozen_string_literal: true

module Contexts
  # Context for workflow decomposition that queries the context graph service.
  # This context class automatically loads relevant context from parent workflows,
  # workers, and memory stores using vector similarity search across the graph.
  class WorkflowContext < BaseContext
    attr_reader :workflow_id, :goal, :max_depth

    # @param workflow_id [String] ID of the workflow requesting context
    # @param goal [String] The goal being worked on
    # @param max_depth [Integer] Maximum depth for decomposition
    def initialize(workflow_id:, goal:, max_depth: nil)
      raise ArgumentError, "workflow_id is required" if workflow_id.nil? || workflow_id.empty?
      raise ArgumentError, "goal is required" if goal.nil? || goal.empty?

      super()
      @workflow_id = workflow_id
      @goal = goal
      @max_depth = max_depth

      load_from_graph
    end

    private

    # Query the context graph for relevant information
    def load_from_graph
      # Query for codebase/architecture context
      load_codebase_context

      # Query for related goals
      load_goal_context

      # Query for prior findings
      load_findings_context

      # Query for decisions and workflow context
      load_workflow_context
    end

    # Load codebase and architecture context
    def load_codebase_context
      results = ContextGraphService.instance.query(
        workflow_id: @workflow_id,
        context_type: :codebase_summary,
        query_vector: "codebase architecture structure overview",
        threshold: 0.7,
        limit: 3
      )

      return if results.empty?

      content = format_results_section("Codebase Context", results)
      add(
        content: content,
        topics: ["codebase", "architecture"],
        source: "context_graph"
      )
    rescue StandardError => e
      Rails.logger.warn "[WorkflowContext] Failed to load codebase context: #{e.message}"
    end

    # Load related goals and objectives
    def load_goal_context
      results = ContextGraphService.instance.query(
        workflow_id: @workflow_id,
        context_type: :current_goal,
        query_vector: @goal,
        threshold: 0.75,
        limit: 5
      )

      return if results.empty?

      content = format_results_section("Related Goals", results)
      add(
        content: content,
        topics: ["goals", "objectives"],
        source: "context_graph"
      )
    rescue StandardError => e
      Rails.logger.warn "[WorkflowContext] Failed to load goal context: #{e.message}"
    end

    # Load prior findings and research
    def load_findings_context
      results = ContextGraphService.instance.query(
        workflow_id: @workflow_id,
        context_type: :findings,
        query_vector: @goal,
        threshold: 0.7,
        limit: 10
      )

      return if results.empty?

      content = format_results_section("Prior Findings", results)
      add(
        content: content,
        topics: ["findings", "research"],
        source: "context_graph"
      )
    rescue StandardError => e
      Rails.logger.warn "[WorkflowContext] Failed to load findings context: #{e.message}"
    end

    # Load workflow decisions and context
    def load_workflow_context
      # Load recent decisions
      decision_results = ContextGraphService.instance.query(
        workflow_id: @workflow_id,
        context_type: :decision,
        query_vector: @goal,
        threshold: 0.7,
        limit: 5
      )

      if decision_results.any?
        content = format_results_section("Recent Decisions", decision_results)
        add(
          content: content,
          topics: ["decisions", "reasoning"],
          source: "context_graph"
        )
      end

      # Load workflow context entries
      context_results = ContextGraphService.instance.query(
        workflow_id: @workflow_id,
        context_type: :workflow_context,
        query_vector: @goal,
        threshold: 0.7,
        limit: 5
      )

      if context_results.any?
        content = format_results_section("Workflow Context", context_results)
        add(
          content: content,
          topics: ["workflow", "context"],
          source: "context_graph"
        )
      end
    rescue StandardError => e
      Rails.logger.warn "[WorkflowContext] Failed to load workflow context: #{e.message}"
    end

    # Format results into a readable section
    # @param title [String] Section title
    # @param results [Array<Hash>] Query results from graph service
    # @return [String] Formatted section
    def format_results_section(title, results)
      lines = ["## #{title}", ""]
      
      results.each do |result|
        memory = result[:memory]
        score = result[:final_score]
        distance = result[:path_distance]
        
        # Format the memory content
        memory_text = if memory.respond_to?(:to_s)
          memory.to_s
        elsif memory.respond_to?(:content)
          memory.content
        elsif memory.is_a?(Hash)
          memory.inspect
        else
          memory.inspect
        end

        # Add with relevance score and distance info
        relevance_pct = (score * 100).round
        lines << "- #{memory_text.truncate(200)} (relevance: #{relevance_pct}%, distance: #{distance})"
      end

      lines.join("\n")
    end
  end
end
