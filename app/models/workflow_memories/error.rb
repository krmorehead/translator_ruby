# frozen_string_literal: true

module WorkflowMemories
  # Memory entry for errors during workflow execution
  class Error < BaseMemory
    attr_reader :error_message, :error_class

    # @param error_message [String] The error message
    # @param error_class [String] The error class name
    # @param checkpoint_id [String] Checkpoint at time of error
    # @param state [Symbol] Workflow state when error occurred
    def initialize(error_message:, error_class:, checkpoint_id:, state:)
      raise TypeError, "error_message must be a String, got #{error_message.class}" unless error_message.is_a?(String)
      raise TypeError, "error_class must be a String, got #{error_class.class}" unless error_class.is_a?(String)
      raise ArgumentError, "error_message cannot be empty" if error_message.empty?

      @error_message = error_message.freeze
      @error_class = error_class.freeze
      
      super(checkpoint_id: checkpoint_id, state: state)
      freeze
    end

    # Content for vectorization - error type and message
    #
    # @return [String] Text to vectorize
    def vectorizable_content
      "Error #{@error_class} in state #{@state}: #{@error_message}"
    end

    # Serialize to hash
    #
    # @return [Hash] Serialized representation
    def to_h
      super.merge(
        error_message: @error_message,
        error_class: @error_class
      )
    end

  # Deserialize from hash
  #
  # @param hash [Hash] Serialized error
  # @return [Error] Reconstructed error
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    new(
      error_message: hash[:error_message] || hash[:error],
      error_class: hash[:error_class] || "StandardError",
      checkpoint_id: hash[:checkpoint_id],
      state: hash[:state].to_sym
    )
  end
  end
end

