# frozen_string_literal: true

module Contexts
  # Context for tracking action execution history.
  # Provides formatted summaries for planning prompts and cache key generation.
  #
  # Actions are recorded with their name, arguments, result, and iteration.
  # The context knows how to format itself for different uses:
  # - Planning prompts: recent actions summary
  # - Cache keys: deterministic hash of relevant state
  # - Debugging: full action history
  #
  # @example Recording actions
  #   context = ActionHistoryContext.new
  #   context.record_action(
  #     name: :search_files,
  #     arguments: { pattern: "calculator" },
  #     result: { success: true, count: 3 },
  #     iteration: 1
  #   )
  #
  class ActionHistoryContext < BaseContext
    attr_reader :actions

    def initialize
      super()
      @actions = []
    end

    # Record an executed action
    # @param name [Symbol, String] Action name
    # @param arguments [Hash] Action arguments
    # @param result [Hash] Action result (must have :success key)
    # @param iteration [Integer] Iteration number when this was executed
    # @param cached [Boolean] Whether result was from cache
    # @return [Hash] The recorded action
    def record_action(name:, arguments:, result:, iteration:, cached: false)
      action = {
        id: SecureRandom.uuid,
        name: name.to_sym,
        arguments: arguments,
        success: result[:success],
        result_summary: extract_result_summary(result),
        iteration: iteration,
        cached: cached,
        timestamp: Time.now.utc.iso8601
      }

      @actions << action

      # Add to entries for general context queries
      status = result[:success] ? "success" : "failed"
      add(
        content: "#{name}(#{arguments.to_json.truncate(100)}): #{status}",
        topics: ["action", name.to_s, status],
        source: "action_history",
        metadata: { action_id: action[:id], iteration: iteration }
      )

      action
    end

    # Get recent actions
    # @param limit [Integer] Maximum actions to return
    # @return [Array<Hash>] Recent actions, most recent first
    def recent_actions(limit: 5)
      @actions.last(limit)
    end

    # Get actions by name
    # @param name [Symbol, String] Action name
    # @return [Array<Hash>] Actions with that name
    def actions_by_name(name)
      @actions.select { |a| a[:name] == name.to_sym }
    end

    # Get successful actions
    # @return [Array<Hash>] Successful actions
    def successful_actions
      @actions.select { |a| a[:success] }
    end

    # Get failed actions
    # @return [Array<Hash>] Failed actions
    def failed_actions
      @actions.reject { |a| a[:success] }
    end

    # Format recent actions for planning prompt
    # @param limit [Integer] Number of recent actions to include
    # @return [String] Formatted action summary
    def recent_actions_summary(limit: 5)
      return "No actions executed yet." if @actions.empty?

      lines = ["## Recent Actions"]
      recent_actions(limit: limit).each do |action|
        status = action[:success] ? "✓" : "✗"
        cached = action[:cached] ? " (cached)" : ""
        args = action[:arguments].to_json.truncate(50)
        lines << "#{status} #{action[:name]}(#{args})#{cached}"
        lines << "   → #{action[:result_summary]}" if action[:result_summary]
      end

      lines.join("\n")
    end

    # Format full action summary for planning
    # @return [String] Complete action summary
    def action_summary
      return "No actions executed." if @actions.empty?

      parts = []
      parts << "Total actions: #{@actions.size}"
      parts << "Successful: #{successful_actions.size}"
      parts << "Failed: #{failed_actions.size}"
      parts << "Cached hits: #{@actions.count { |a| a[:cached] }}"
      parts << ""
      parts << recent_actions_summary

      parts.join("\n")
    end

    # Compute hash for cache key generation
    # Based on action count and last action - deterministic
    # @return [String] MD5 hash
    def compute_hash
      content = {
        action_count: @actions.size,
        last_action: @actions.last&.slice(:name, :arguments, :success),
        last_iteration: @actions.last&.dig(:iteration)
      }
      Digest::MD5.hexdigest(content.to_json)
    end

    # Format for prompt output
    # @param question [String] Optional question (unused, for interface compliance)
    # @return [String] Formatted action history
    def format_for_prompt(question = nil)
      action_summary
    end

    # Check if an action with same name and arguments was already executed
    # @param name [Symbol, String] Action name
    # @param arguments [Hash] Action arguments
    # @return [Hash, nil] Previous action if found
    def find_previous_execution(name, arguments)
      @actions.reverse.find do |action|
        action[:name] == name.to_sym && action[:arguments] == arguments
      end
    end

    # Serialize to hash
    # @return [Hash]
    def to_h
      super.merge(
        actions: @actions,
        total_count: @actions.size,
        success_count: successful_actions.size
      )
    end

    # Deserialize from hash
    # @param hash [Hash] Serialized data
    # @return [ActionHistoryContext]
    def self.from_h(hash)
      context = new
      actions = hash[:actions] || hash["actions"] || []
      context.instance_variable_set(:@actions, actions.map(&:deep_symbolize_keys))

      # Restore entries
      entries_data = hash[:entries] || hash["entries"] || []
      entries_data.each do |entry_data|
        context.add(
          content: entry_data[:content] || entry_data["content"],
          topics: entry_data[:topics] || entry_data["topics"] || [],
          source: entry_data[:source] || entry_data["source"],
          metadata: entry_data[:metadata] || entry_data["metadata"] || {}
        )
      end

      context
    end


    def extract_result_summary(result)
      return result[:error] if result[:error]
      return result[:summary] if result[:summary]
      return "Found #{result[:count]} items" if result[:count]
      return "#{result[:findings].size} findings" if result[:findings]

      result[:success] ? "completed" : "failed"
    end
  end
end

