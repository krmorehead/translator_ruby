# frozen_string_literal: true

module WorkflowMemories
  # Represents a research finding from code analysis
  # Immutable value object with fail-fast validation
  class Finding
    attr_reader :id, :text, :relevance, :confidence, :file_path, :pass_number, :sub_question_id

    def initialize(text:, file_path:, confidence:, pass_number:, sub_question_id: nil, relevance: nil, id: nil)
      # Fail-fast validation
      raise ArgumentError, "text is required" if text.nil? || text.to_s.empty?
      raise ArgumentError, "file_path is required" if file_path.nil? || file_path.to_s.empty?
      raise ArgumentError, "confidence must be a number" unless confidence.is_a?(Numeric)
      raise ArgumentError, "confidence must be between 0 and 1" unless confidence.between?(0, 1)
      raise ArgumentError, "pass_number must be a positive integer" unless pass_number.is_a?(Integer) && pass_number > 0

      @id = id || SecureRandom.uuid
      @text = text.to_s.freeze
      @file_path = file_path.to_s.freeze
      @confidence = confidence
      @pass_number = pass_number
      @sub_question_id = sub_question_id.to_s.freeze if sub_question_id
      @relevance = relevance.to_s.freeze if relevance

      freeze
    end

    # Serialize to hash for persistence
    def to_h
      {
        id: @id,
        text: @text,
        file_path: @file_path,
        confidence: @confidence,
        pass_number: @pass_number,
        sub_question_id: @sub_question_id,
        relevance: @relevance
      }.compact
    end

    # Deserialize from hash
    def self.from_h(hash)
      raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      raise ArgumentError, "text is required in hash" unless hash[:text] || hash["text"]
      raise ArgumentError, "file_path is required in hash" unless hash[:file_path] || hash["file_path"]

      new(
        id: hash[:id] || hash["id"],
        text: hash[:text] || hash["text"],
        file_path: hash[:file_path] || hash["file_path"],
        confidence: hash[:confidence] || hash["confidence"] || 0.5,
        pass_number: hash[:pass_number] || hash["pass_number"] || 1,
        sub_question_id: hash[:sub_question_id] || hash["sub_question_id"],
        relevance: hash[:relevance] || hash["relevance"]
      )
    end

    def ==(other)
      other.is_a?(Finding) &&
        other.id == @id &&
        other.text == @text &&
        other.file_path == @file_path
    end

    alias eql? ==

    def hash
      [@id, @text, @file_path].hash
    end
  end
end

