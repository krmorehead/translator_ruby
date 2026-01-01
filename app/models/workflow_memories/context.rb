# frozen_string_literal: true

module WorkflowMemories
  # Memory entry for context additions during workflow execution
  class Context < BaseMemory
    attr_reader :context_data

    # @param context_data [Hash] Context information added
    # @param checkpoint_id [String] Checkpoint at time of context addition
    # @param state [Symbol] Workflow state at time of addition
    def initialize(context_data:, checkpoint_id:, state:)
      raise TypeError, "context_data must be a Hash, got #{context_data.class}" unless context_data.is_a?(Hash)
      raise ArgumentError, "context_data cannot be empty" if context_data.empty?

      @context_data = context_data.freeze
      
      super(checkpoint_id: checkpoint_id, state: state)
      freeze
    end

    # Content for vectorization - summarizes context keys and values
    #
    # @return [String] Text to vectorize
    def vectorizable_content
      parts = @context_data.map do |key, value|
        "#{key}: #{summarize_value(value)}"
      end
      "Context added in state #{@state}: #{parts.join(', ')}"
    end

    # Serialize to hash
    #
    # @return [Hash] Serialized representation
    def to_h
      super.merge(context_data: @context_data)
    end

  # Deserialize from hash
  #
  # @param hash [Hash] Serialized context
  # @return [Context] Reconstructed context
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    new(
      context_data: hash[:context_data] || {},
      checkpoint_id: hash[:checkpoint_id],
      state: hash[:state].to_sym
    )
  end

    private

    def summarize_value(value)
      case value
      when String
        value.length > 50 ? "#{value[0..47]}..." : value
      when Array
        "#{value.length} items"
      when Hash
        "#{value.keys.join(', ')}"
      else
        value.to_s
      end
    end
  end
end

