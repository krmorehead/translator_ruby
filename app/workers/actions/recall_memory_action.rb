# frozen_string_literal: true

module Actions
  # Action to retrieve information from campaign memory.
  # Uses the memory store's context to find relevant information.
  class RecallMemoryAction < BaseAction
    def execute(query:, category: nil)
      # Build a context with relevant memories
      context = memory_store.full_context

      # Get entries relevant to the query
      relevant = context.relevant_to(query, limit: 5)

      if relevant.empty?
        success_result(
          result: "No memories found matching: #{query}",
          summary: "Memory search returned no results",
          findings: []
        )
      else
        memories = relevant.map(&:content)
        success_result(
          result: memories.join("\n"),
          summary: "Found #{memories.size} relevant memories",
          findings: memories.map { |m| { text: m, source: "memory" } }
        )
      end
    end
  end
end

