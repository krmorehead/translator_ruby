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
    # @return [Actions::BaseAction] The recorded action
    def record_action(name:, arguments:, result:, iteration:, cached: false)
      action = Actions::BaseAction.new(
        name: name,
        arguments: arguments,
        result: result,
        iteration: iteration,
        cached: cached
      )

      @actions << action

      # Add to entries for general context queries
      status = result[:success] ? "success" : "failed"
      add(
        content: "#{name}(#{arguments.to_json.truncate(100)}): #{status}",
        topics: ["action", name.to_s, status],
        source: "action_history",
        metadata: { action_id: action.id, iteration: iteration }
      )

      action
    end

    # Get recent actions
    # @param limit [Integer] Maximum actions to return
    # @return [Array<Actions::BaseAction>] Recent actions, most recent first
    def recent_actions(limit: 5)
      raise ArgumentError, "limit must be a positive Integer" unless limit.is_a?(Integer) && limit > 0
      @actions.last(limit)
    end

    # Get actions by name
    # @param name [Symbol, String] Action name
    # @return [Array<Actions::BaseAction>] Actions with that name
    def actions_by_name(name)
      raise ArgumentError, "name must be a Symbol or String" unless name.is_a?(Symbol) || name.is_a?(String)
      @actions.select { |a| a.name == name.to_sym }
    end

    # Get successful actions
    # @return [Array<Actions::BaseAction>] Successful actions
    def successful_actions
      @actions.select(&:successful?)
    end

    # Get failed actions
    # @return [Array<Actions::BaseAction>] Failed actions
    def failed_actions
      @actions.select(&:failed?)
    end

    # Format recent actions for planning prompt
    # @param limit [Integer] Number of recent actions to include
    # @return [String] Formatted action summary
    def recent_actions_summary(limit: 5)
      return "No actions executed yet." if @actions.empty?

      lines = ["## Recent Actions"]
      recent_actions(limit: limit).each do |action|
        status = action.successful? ? "✓" : "✗"
        cached = action.cached ? " (cached)" : ""
        args = action.arguments.to_json.truncate(50)
        lines << "#{status} #{action.name}(#{args})#{cached}"
        lines << "   → #{action.result_summary}" if action.result_summary
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
      parts << "Cached hits: #{@actions.count(&:cached)}"
      parts << ""
      parts << recent_actions_summary

      parts.join("\n")
    end

    # Compute hash for cache key generation
    # Based on action count and last action - deterministic
    # @return [String] MD5 hash
    def compute_hash
      last_action = @actions.last
      content = {
        action_count: @actions.size,
        last_action: last_action ? { name: last_action.name, arguments: last_action.arguments, success: last_action.success } : nil,
        last_iteration: last_action&.iteration
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
    # @return [Actions::BaseAction, nil] Previous action if found
    def find_previous_execution(name, arguments)
      raise ArgumentError, "name must be a Symbol or String" unless name.is_a?(Symbol) || name.is_a?(String)
      raise TypeError, "arguments must be a Hash" unless arguments.is_a?(Hash)
      
      @actions.reverse.find do |action|
        action.name == name.to_sym && action.arguments == arguments
      end
    end

    # Serialize to hash
    # @return [Hash]
    def to_h
      super.merge(
        actions: @actions.map(&:to_h),
        total_count: @actions.size,
        success_count: successful_actions.size
      )
    end

    # Deserialize from hash
    # @param hash [Hash] Serialized data
    # @return [ActionHistoryContext]
    def self.from_h(hash)
      raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
      raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
      raise ArgumentError, "Missing required key :actions" unless hash.key?(:actions)
      raise TypeError, "actions must be an Array" unless hash[:actions].is_a?(Array)

      context = new
      
      # Reconstruct actions as Action objects
      actions = hash[:actions].map { |action_hash| Actions::BaseAction.from_h(action_hash) }
      context.instance_variable_set(:@actions, actions)

      # Restore entries as Entry objects
      load_entries_from_h(context, hash)
      load_sub_contexts_from_h(context, hash)

      context
    end
  end
end

