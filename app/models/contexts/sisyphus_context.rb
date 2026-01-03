# frozen_string_literal: true

module Contexts
  # Context object for Sisyphus Agent Worker execution.
  # Captures execution environment, plan details, and runtime state
  # for use in prompts and workflows.
  #
  # Following OOP patterns: strict validation, fail-fast, immutability via recreation.
  class SisyphusContext < BaseContext
    attr_reader :codebase_path, :plan_goal, :plan_id, :execution_id,
                :current_milestone, :current_step, :execution_metadata

    # Initialize Sisyphus execution context
    #
    # @param codebase_path [String] Absolute path to the codebase being modified
    # @param plan_goal [String] The overall goal of the execution plan
    # @param plan_id [String] Unique identifier for the execution plan
    # @param execution_id [String] Unique identifier for this execution
    # @param current_milestone [Hash, nil] Current milestone being executed {number:, title:, description:}
    # @param current_step [Hash, nil] Current step being executed {number:, title:, intent:}
    # @param execution_metadata [Hash] Additional execution metadata
    def initialize(
      codebase_path:,
      plan_goal:,
      plan_id:,
      execution_id:,
      current_milestone: nil,
      current_step: nil,
      execution_metadata: {}
    )
      super() # Initialize BaseContext

      # Strict type validation
      raise TypeError, "codebase_path must be a String, got #{codebase_path.class}" unless codebase_path.is_a?(String)
      raise TypeError, "plan_goal must be a String, got #{plan_goal.class}" unless plan_goal.is_a?(String)
      raise TypeError, "plan_id must be a String, got #{plan_id.class}" unless plan_id.is_a?(String)
      raise TypeError, "execution_id must be a String, got #{execution_id.class}" unless execution_id.is_a?(String)
      raise TypeError, "execution_metadata must be a Hash, got #{execution_metadata.class}" unless execution_metadata.is_a?(Hash)

      # Value validation
      raise ArgumentError, "codebase_path cannot be empty" if codebase_path.strip.empty?
      raise ArgumentError, "plan_goal cannot be empty" if plan_goal.strip.empty?
      raise ArgumentError, "plan_id cannot be empty" if plan_id.strip.empty?
      raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?

      # Path validation
      expanded_path = File.expand_path(codebase_path)
      raise ArgumentError, "codebase_path must be a valid directory: #{codebase_path}" unless Dir.exist?(expanded_path)

      @codebase_path = expanded_path
      @plan_goal = plan_goal
      @plan_id = plan_id
      @execution_id = execution_id
      @current_milestone = current_milestone
      @current_step = current_step
      @execution_metadata = execution_metadata.freeze
    end

    # Create updated context with new milestone/step (immutable pattern)
    #
    # @param milestone [Hash, nil] New current milestone
    # @param step [Hash, nil] New current step
    # @param metadata [Hash] Additional metadata to merge
    # @return [SisyphusContext] New context with updated values
    def with_current_position(milestone: nil, step: nil, metadata: {})
      self.class.new(
        codebase_path: @codebase_path,
        plan_goal: @plan_goal,
        plan_id: @plan_id,
        execution_id: @execution_id,
        current_milestone: milestone || @current_milestone,
        current_step: step || @current_step,
        execution_metadata: @execution_metadata.merge(metadata)
      )
    end

    # Serialize for prompt usage
    # Includes all execution context needed by LLM
    #
    # @return [Hash] Serialized context for prompts
    def to_h
      base_hash = super # Get BaseContext serialization

      base_hash.merge(
        sisyphus_context: {
          codebase_path: @codebase_path,
          plan_goal: @plan_goal,
          plan_id: @plan_id,
          execution_id: @execution_id,
          current_milestone: @current_milestone,
          current_step: @current_step,
          execution_metadata: @execution_metadata
        }
      )
    end

    # Format context specifically for Sisyphus prompts
    # Provides structured execution context
    #
    # @return [String] Formatted context string for prompts
    def format_for_sisyphus_prompt
      sections = []

      sections << "# Execution Context"
      sections << ""
      sections << "**Codebase Path**: `#{@codebase_path}`"
      sections << "**Plan Goal**: #{@plan_goal}"
      sections << "**Execution ID**: #{@execution_id}"
      sections << ""

      if @current_milestone
        sections << "## Current Milestone"
        sections << "- **Number**: #{@current_milestone[:number]}"
        sections << "- **Title**: #{@current_milestone[:title]}"
        sections << "- **Description**: #{@current_milestone[:description]}" if @current_milestone[:description]
        sections << ""
      end

      if @current_step
        sections << "## Current Step"
        sections << "- **Number**: #{@current_step[:number]}"
        sections << "- **Title**: #{@current_step[:title]}"
        sections << "- **Intent**: #{@current_step[:intent]}"
        sections << ""
      end

      unless @execution_metadata.empty?
        sections << "## Execution Metadata"
        @execution_metadata.each do |key, value|
          sections << "- **#{key.to_s.titleize}**: #{value}"
        end
        sections << ""
      end

      # Include any context entries from BaseContext
      if entries.any?
        sections << "## Additional Context"
        sections << format_for_prompt(@plan_goal, format: :brief)
      end

      sections.join("\n")
    end

    # Deserialize from hash
    #
    # @param data [Hash] Serialized context data
    # @return [SisyphusContext] Deserialized context
    def self.from_h(data)
      raise TypeError, "data must be a Hash, got #{data.class}" unless data.is_a?(Hash)
      raise ArgumentError, "data must contain :sisyphus_context key" unless data.key?(:sisyphus_context)

      sisyphus_data = data[:sisyphus_context]

      context = new(
        codebase_path: sisyphus_data[:codebase_path],
        plan_goal: sisyphus_data[:plan_goal],
        plan_id: sisyphus_data[:plan_id],
        execution_id: sisyphus_data[:execution_id],
        current_milestone: sisyphus_data[:current_milestone],
        current_step: sisyphus_data[:current_step],
        execution_metadata: sisyphus_data[:execution_metadata] || {}
      )

      # Load BaseContext entries and sub-contexts
      load_entries_from_h(context, data) if data[:entries]
      load_sub_contexts_from_h(context, data) if data[:sub_contexts]

      context
    end

    # Validate that an object is a SisyphusContext
    #
    # @param obj [Object] Object to validate
    # @raise [TypeError] If object is not a SisyphusContext
    def self.validate!(obj)
      unless obj.is_a?(SisyphusContext)
        raise TypeError, "Expected SisyphusContext, got #{obj.class}. Example: SisyphusContext.new(codebase_path: '/path', plan_goal: 'goal', plan_id: 'id', execution_id: 'id')"
      end
    end
  end
end


