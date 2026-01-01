# frozen_string_literal: true

module WorkflowMemories
  # Memory entry for state transitions during workflow execution
  class StateTransition < BaseMemory
    attr_reader :from, :to, :event, :source, :payload, :duration

    # @param from [Symbol] Source state
    # @param to [Symbol] Target state  
    # @param event [Symbol] Event that triggered transition
    # @param source [String] Name of worker/workflow that triggered transition
    # @param payload [Hash] Additional transition data
    # @param duration [Float] Time spent in previous state
    # @param checkpoint_id [String] Checkpoint at time of transition
    # @param state [Symbol] New state after transition (same as 'to')
    def initialize(from:, to:, event:, source:, payload:, duration:, checkpoint_id:, state:)
      raise TypeError, "from must be a Symbol, got #{from.class}" unless from.is_a?(Symbol)
      raise TypeError, "to must be a Symbol, got #{to.class}" unless to.is_a?(Symbol)
      raise TypeError, "event must be a Symbol, got #{event.class}" unless event.is_a?(Symbol)
      raise TypeError, "source must be a String, got #{source.class}" unless source.is_a?(String)
      raise TypeError, "payload must be a Hash, got #{payload.class}" unless payload.is_a?(Hash)
      raise TypeError, "duration must be Numeric, got #{duration.class}" unless duration.is_a?(Numeric)

      @from = from.freeze
      @to = to.freeze
      @event = event.freeze
      @source = source.freeze
      @payload = payload.freeze
      @duration = duration.freeze
      
      super(checkpoint_id: checkpoint_id, state: state)
      freeze
    end

    # Content for vectorization - focuses on transition meaning
    #
    # @return [String] Text to vectorize
    def vectorizable_content
      payload_summary = @payload.empty? ? "" : " with #{@payload.keys.join(', ')}"
      "#{@source} transitioned from #{@from} to #{@to} via #{@event}#{payload_summary}"
    end

    # Serialize to hash
    #
    # @return [Hash] Serialized representation
    def to_h
      super.merge(
        from: @from,
        to: @to,
        event: @event,
        source: @source,
        payload: @payload,
        duration: @duration
      )
    end

  # Deserialize from hash
  #
  # @param hash [Hash] Serialized transition
  # @return [StateTransition] Reconstructed transition
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    new(
      from: hash[:from].to_sym,
      to: hash[:to].to_sym,
      event: hash[:event].to_sym,
      source: hash[:source] || "Unknown",
      payload: hash[:payload] || {},
      duration: hash[:duration] || hash[:duration_in_state] || 0.0,  # Handle legacy key
      checkpoint_id: hash[:checkpoint_id],
      state: (hash[:state] || hash[:to]).to_sym  # state might not be present in old format
    )
  end
  end
end

