# frozen_string_literal: true

# DSL for registering and managing actions available to an agent.
# Actions are small, composable units of work that the agent can execute.
#
# @example Registering actions in a worker
#   class ResearchAgent < AgentWorker
#     include ActionRegistry
#
#     register_action :search_files,
#       class_name: "Actions::SearchFilesAction",
#       description: "Search for files matching a pattern",
#       parameters: {
#         pattern: { type: :string, required: true, description: "Search pattern" },
#         path: { type: :string, required: false, description: "Directory to search" }
#       }
#
#     register_action :analyze_file,
#       class_name: "Actions::AnalyzeFileAction",
#       description: "Analyze a file for relevant information"
#   end
#
module ActionRegistry
  extend ActiveSupport::Concern

  included do
    class_attribute :_registered_actions, default: {}
  end

  class_methods do
    # Register an action for this agent type
    # @param name [Symbol] The action identifier
    # @param options [Hash] Action configuration
    # @option options [String, Class] :class_name The action class (required)
    # @option options [String] :description Human-readable description for planner
    # @option options [Hash] :parameters Parameter definitions for the action
    # @option options [Array<Symbol>] :requires Dependencies this action needs
    # @option options [Symbol] :category Action category for grouping
    def register_action(name, **options)
      action_class = resolve_action_class(options[:class_name] || options[:class])

      self._registered_actions = _registered_actions.merge(
        name.to_sym => {
          class: action_class,
          description: options[:description] || name.to_s.humanize,
          parameters: options[:parameters] || {},
          requires: Array(options[:requires]),
          category: options[:category] || :general
        }
      )
    end

    # Get all registered actions
    # @return [Hash] Action name => configuration hash
    def registered_actions
      _registered_actions
    end

    # Get action definitions formatted for the planner prompt
    # @return [Array<Hash>] Action definitions
    def action_definitions
      _registered_actions.map do |name, config|
        {
          name: name.to_s,
          description: config[:description],
          parameters: format_parameters(config[:parameters]),
          category: config[:category]
        }
      end
    end

    # Get actions by category
    # @param category [Symbol] The category to filter by
    # @return [Hash] Filtered actions
    def actions_in_category(category)
      _registered_actions.select { |_, config| config[:category] == category }
    end

    # Check if an action is registered
    # @param name [Symbol, String] The action name
    # @return [Boolean]
    def action_registered?(name)
      _registered_actions.key?(name.to_sym)
    end

    private

    def resolve_action_class(class_ref)
      # class_ref must be provided - it's required
      class_ref.to_s.constantize
    end

    def format_parameters(params)
      return {} if params.nil?

      params.transform_values do |config|
        # Handle both formats:
        # { param: "description" } - simple string description
        # { param: { type: :string, required: true, description: "desc" } } - full config
        if config.is_a?(String)
          { type: :string, required: false, description: config }
        else
          {
            type: config[:type] || :string,
            required: config[:required] || false,
            description: config[:description] || ""
          }
        end
      end
    end
  end

  # Instance methods

  # Get the action class for a given name
  # @param name [Symbol, String] The action name
  # @return [Class] The action class
  # @raise [ArgumentError] If action is not registered
  def action_class_for(name)
    config = self.class._registered_actions[name.to_sym]
    raise ArgumentError, "Unknown action: #{name}" unless config

    config[:class].to_s.constantize
  end

  # Check if an action is available
  # @param name [Symbol, String] The action name
  # @return [Boolean]
  def action_available?(name)
    config = self.class._registered_actions[name.to_sym]
    return false unless config

    # Check if all dependencies are satisfied
    config[:requires].all? { |dep| dependency_satisfied?(dep) }
  end

  # Get available actions (those whose dependencies are satisfied)
  # @return [Array<Symbol>] Available action names
  def available_action_names
    self.class._registered_actions.keys.select { |name| action_available?(name) }
  end

  # Execute an action by name
  # @param name [Symbol, String] The action name
  # @param arguments [Hash] Arguments to pass to the action
  # @return [Hash] The action result
  def execute_registered_action(name, **arguments)
    action_class = action_class_for(name)

    action = action_class.new(
      agent: self,
      memory_store: memory_store,
      path: path,
      goal: goal
    )

    action.execute(**arguments)
  end

  private

  # Check if a dependency is satisfied
  # Override in subclasses for custom dependency logic
  # @param dependency [Symbol] The dependency to check
  # @return [Boolean]
  def dependency_satisfied?(dependency)
    case dependency
    when :memory_store
      memory_store.present?
    when :path
      path.present?
    when :llm
      ENV["API_KEY"].present? || ENV["LLM_URL"].present?
    else
      true
    end
  end
end
