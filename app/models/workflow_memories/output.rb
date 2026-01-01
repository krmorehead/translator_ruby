# frozen_string_literal: true

module WorkflowMemories
  # Memory entry for outputs produced during workflow execution
  class Output < BaseMemory
    attr_reader :output_data

    # @param output_data [Hash] Output data produced by workflow
    # @param checkpoint_id [String] Checkpoint at time of output
    # @param state [Symbol] Workflow state at time of output
    def initialize(output_data:, checkpoint_id:, state:)
      raise TypeError, "output_data must be a Hash, got #{output_data.class}" unless output_data.is_a?(Hash)
      raise ArgumentError, "output_data cannot be empty" if output_data.empty?

      @output_data = output_data.freeze
      
      super(checkpoint_id: checkpoint_id, state: state)
      freeze
    end

    # Content for vectorization - summarizes output keys and types
    #
    # @return [String] Text to vectorize
    def vectorizable_content
      parts = @output_data.map do |key, value|
        "#{key}: #{value_type_summary(value)}"
      end
      "Output produced in state #{@state}: #{parts.join(', ')}"
    end

    # Serialize to hash
    #
    # @return [Hash] Serialized representation
    def to_h
      super.merge(output_data: @output_data)
    end

  # Deserialize from hash
  #
  # @param hash [Hash] Serialized output
  # @return [Output] Reconstructed output
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    new(
      output_data: hash[:output_data] || hash,
      checkpoint_id: hash[:checkpoint_id],
      state: hash[:state].to_sym
    )
  end

    private

    def value_type_summary(value)
      case value
      when String
        "String(#{value.length} chars)"
      when Array
        "Array(#{value.length} items)"
      when Hash
        "Hash(#{value.keys.join(', ')})"
      when Numeric
        "Number(#{value})"
      when TrueClass, FalseClass
        "Boolean(#{value})"
      else
        value.class.name
      end
    end
  end
end

