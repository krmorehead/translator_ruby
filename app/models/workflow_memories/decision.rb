# frozen_string_literal: true

module WorkflowMemories
  # Memory entry for decisions made during workflow execution
  class Decision < BaseMemory
    attr_reader :decision, :rationale, :context

    # @param decision [String] The decision that was made
    # @param rationale [String] Why this decision was made
    # @param context [Hash] Context that informed the decision
    # @param checkpoint_id [String] Checkpoint at time of decision
    # @param state [Symbol] Workflow state at time of decision
    def initialize(decision:, rationale:, context:, checkpoint_id:, state:)
      raise TypeError, "decision must be a String, got #{decision.class}" unless decision.is_a?(String)
      raise TypeError, "rationale must be a String, got #{rationale.class}" unless rationale.is_a?(String)
      raise TypeError, "context must be a Hash, got #{context.class}" unless context.is_a?(Hash)
      raise ArgumentError, "decision cannot be empty" if decision.empty?
      raise ArgumentError, "rationale cannot be empty" if rationale.empty?

      @decision = decision.freeze
      @rationale = rationale.freeze
      @context = context.freeze
      
      super(checkpoint_id: checkpoint_id, state: state)
      freeze
    end

    # Content for vectorization - combines decision and rationale
    # Avoids redundant keys, focuses on semantic meaning
    #
    # @return [String] Text to vectorize
    def vectorizable_content
      "Decision: #{@decision}. Rationale: #{@rationale}. State: #{@state}"
    end

    # Serialize to hash
    #
    # @return [Hash] Serialized representation
    def to_h
      super.merge(
        decision: @decision,
        rationale: @rationale,
        context: @context
      )
    end

  # Deserialize from hash
  #
  # @param hash [Hash] Serialized decision
  # @return [Decision] Reconstructed decision
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    new(
      decision: hash[:decision],
      rationale: hash[:rationale],
      context: hash[:context] || {},
      checkpoint_id: hash[:checkpoint_id],
      state: hash[:state].to_sym
    )
  end
  end
end

