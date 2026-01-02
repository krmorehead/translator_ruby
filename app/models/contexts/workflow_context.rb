# frozen_string_literal: true

# WorkflowContext that queries the ContextGraphService for relevant context
# Automatically gathers context from the graph based on goal
module Contexts
  class WorkflowContext < BaseContext
    attr_reader :id, :goal

    def initialize(goal:)
      super()
      @id = SecureRandom.uuid
      @goal = goal
      load_from_graph
    end

    # Format context for prompts
    def format_for_prompt(query_text = nil)
      return "No context available" if entries.empty?

      sections = []
      
      # Group entries by topic
      by_topic = entries.group_by { |e| e.topics.first || "general" }
      
      by_topic.each do |topic, topic_entries|
        sections << "## #{topic.to_s.titleize}"
        topic_entries.first(3).each do |entry|
          sections << "- #{entry.content}"
        end
      end
      
      sections.join("\n\n")
    end

    private

    def load_from_graph
      service = ContextGraphService.instance

      # Query for decisions (prior reasoning and choices)
      decision_results = service.query(
        id: @id,
        context_type: :decision,
        query_vector: @goal,
        threshold: 0.6,
        limit: 3
      )

      decision_results.each do |res|
      add(
          content: "Prior Decision: #{res[:memory].decision}",
          topics: ["decisions", "prior_knowledge"],
          source: res[:source],
          metadata: { score: res[:final_score], distance: res[:distance] }
        )
    end

      # Query for goals (related goals and sub-questions)
      goal_results = service.query(
        id: @id,
        context_type: :research_goal,
        query_vector: @goal,
        threshold: 0.7,
        limit: 2
      )

      goal_results.each do |res|
        add(
          content: "Related Goal: #{res[:memory].to_s}",
          topics: ["goals", "research"],
          source: res[:source],
          metadata: { score: res[:final_score], distance: res[:distance] }
        )
    end

      # Query for findings (previous research results)
      finding_results = service.query(
        id: @id,
        context_type: :findings,
        query_vector: "findings relevant to #{@goal}",
        threshold: 0.6,
        limit: 2
      )

      finding_results.each do |res|
        add(
          content: "Prior Finding: #{res[:memory].to_s}",
          topics: ["findings", "prior_research"],
          source: res[:source],
          metadata: { score: res[:final_score], distance: res[:distance] }
        )
      end

      Rails.logger.info "[WorkflowContext] Loaded #{entries.size} context entries from graph"
    end
  end
end
