# frozen_string_literal: true

module Planning
  # Represents a file reference in a project plan.
  # A file reference can be either existing (found during research) or planned (to be created).
  #
  # @example Creating an existing file reference
  #   ref = Planning::FileReference.new(
  #     path: "app/models/user.rb",
  #     description: "User model with authentication",
  #     relevance: "Contains auth logic"
  #   )
  #
  # @example Creating a planned file reference
  #   ref = Planning::FileReference.new(
  #     path: "app/services/payment_service.rb",
  #     description: "Handles payment processing",
  #     created_in_step: "2.3"
  #   )
  class FileReference
    attr_reader :path, :description, :relevance, :created_in_step

    # @param path [String] File path (relative or absolute)
    # @param description [String] Description of the file's purpose
    # @param relevance [String, nil] Why this file is relevant (for existing files)
    # @param created_in_step [String, nil] Step number where this file will be created (for planned files)
    def initialize(path:, description:, relevance: nil, created_in_step: nil)
      validate_types!(path, description, relevance, created_in_step)
      
      @path = normalize_path(path)
      @description = description
      @relevance = relevance
      @created_in_step = created_in_step
    end

    # Check if this is an existing file reference
    # @return [Boolean] true if this represents an existing file
    def existing?
      !@relevance.nil? && @created_in_step.nil?
    end

    # Check if this is a planned file reference
    # @return [Boolean] true if this represents a file to be created
    def planned?
      !@created_in_step.nil? && @relevance.nil?
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation of the file reference
    def to_h
      {
        path: @path,
        description: @description,
        relevance: @relevance,
        created_in_step: @created_in_step
      }.compact
    end

    # Reconstruct a FileReference from a hash
    # @param hash [Hash] Hash containing file reference data
    # @return [Planning::FileReference] Reconstructed file reference
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      new(
        path: hash[:path] || hash["path"],
        description: hash[:description] || hash["description"],
        relevance: hash[:relevance] || hash["relevance"],
        created_in_step: hash[:created_in_step] || hash["created_in_step"]
      )
    end

    private

    def validate_types!(path, description, relevance, created_in_step)
      raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
      raise ArgumentError, "path cannot be empty" if path.strip.empty?
      raise ArgumentError, "description must be a String, got #{description.class}" unless description.is_a?(String)
      raise ArgumentError, "description cannot be empty" if description.strip.empty?
      
      if relevance && !relevance.is_a?(String)
        raise ArgumentError, "relevance must be a String or nil, got #{relevance.class}"
      end
      
      if created_in_step && !created_in_step.is_a?(String)
        raise ArgumentError, "created_in_step must be a String or nil, got #{created_in_step.class}"
      end
      
      # At least one of relevance or created_in_step should be present
      if relevance.nil? && created_in_step.nil?
        raise ArgumentError, "Either relevance (for existing files) or created_in_step (for planned files) must be provided"
      end
    end

    def normalize_path(path)
      # Remove leading/trailing whitespace
      normalized = path.strip
      
      # Remove leading "./" if present
      normalized = normalized.sub(%r{^\./}, "")
      
      normalized
    end
  end
end

