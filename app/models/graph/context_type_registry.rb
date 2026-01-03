# frozen_string_literal: true

# Registry mapping context types to their corresponding memory sections.
# This enables the context graph to know which memory sections to query
# for each type of context request.
module Graph
  class ContextTypeRegistry
    # Build registry dynamically from known memory section types
    TYPES = {}.tap do |types|
      # Workflow memory types (from WorkflowMemoryStore)
      types[:decision] = { sections: [:decisions] }
      types[:state_transition] = { sections: [:state_transitions] }
      types[:workflow_context] = { sections: [:workflow_context] }
      types[:error] = { sections: [:errors] }
      types[:output] = { sections: [:outputs] }
      types[:checkpoint] = { sections: [:checkpoints] }

      # Research memory types (from ResearchMemoryStore)
      types[:research_goal] = { sections: [:research_goal] }
      types[:sub_questions] = { sections: [:sub_questions] }
      types[:context_chain] = { sections: [:context_chain] }
      types[:findings] = { sections: [:findings] }
      types[:discovered_files] = { sections: [:discovered_files] }
      types[:iteration_log] = { sections: [:iteration_log] }
      types[:documentation_cache] = { sections: [:documentation_cache] }
      types[:action_history] = { sections: [:action_history] }

      # Narrative memory types from Memories::Registry
      if defined?(Memories::Registry)
        Memories::Registry::ALL.each do |klass|
          section_name = klass.section_name.to_sym
          types[section_name] = { sections: [section_name] }
        end
      end
    end.freeze

    # Get all registered context types
    # @return [Array<Symbol>] List of registered context type names
    def self.registered_types
      TYPES.keys
    end

    # Get memory sections for a given context type
    # @param context_type [Symbol, String] The context type to look up
    # @return [Array<Symbol>] List of section names for this context type
    def self.sections_for(context_type)
      TYPES[context_type.to_sym]&.fetch(:sections, []) || []
    end

    # Check if a context type is registered
    # @param context_type [Symbol, String] The context type to check
    # @return [Boolean] True if the context type is registered
    def self.registered?(context_type)
      TYPES.key?(context_type.to_sym)
    end
  end
end








