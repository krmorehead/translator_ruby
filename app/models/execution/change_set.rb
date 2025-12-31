# frozen_string_literal: true

module Execution
  # Represents a set of file changes made during execution.
  # Enables diff generation and rollback capabilities.
  #
  # @example Creating a change set
  #   change_set = Execution::ChangeSet.new(
  #     files: {
  #       "app/models/user.rb" => {
  #         change_type: :created,
  #         diff: "+class User\n+end",
  #         before_hash: nil,
  #         after_hash: "abc123"
  #       }
  #     },
  #     checkpoint_id: "git_commit_hash"
  #   )
  #
  # @example With milestone and step tracking
  #   change_set = Execution::ChangeSet.new(
  #     files: {...},
  #     checkpoint_id: "abc123",
  #     milestone_id: "1",
  #     step_id: "1.1",
  #     summary: "Created user model"
  #   )
  class ChangeSet
    # Change types
    CHANGE_TYPES = [
      CREATED = :created,
      MODIFIED = :modified,
      DELETED = :deleted
    ].freeze

    attr_reader :files, :checkpoint_id, :created_at, :milestone_id, :step_id, :summary

    # @param files [Hash<String, Hash>] Map of file path to change details
    #   Each change detail hash must contain:
    #   - change_type [Symbol] One of :created, :modified, :deleted
    #   - diff [String] The unified diff string
    #   - before_hash [String, nil] Git hash before change (nil for created files)
    #   - after_hash [String, nil] Git hash after change (nil for deleted files)
    # @param checkpoint_id [String, nil] Optional git commit hash
    # @param created_at [String, nil] Optional ISO8601 timestamp
    # @param milestone_id [String, nil] Optional milestone identifier
    # @param step_id [String, nil] Optional step identifier
    # @param summary [String, nil] Optional human-readable summary
    def initialize(files:, checkpoint_id: nil, created_at: nil, milestone_id: nil,
                   step_id: nil, summary: nil)
      validate_types!(files, checkpoint_id)
      validate_files_structure!(files)
      
      @files = files
      @checkpoint_id = checkpoint_id
      @created_at = created_at || Time.now.utc.iso8601
      @milestone_id = milestone_id
      @step_id = step_id
      @summary = summary
    end

    # Get the total count of file changes
    # @return [Integer]
    def file_count
      @files.size
    end

    # Get count of modifications
    # @return [Integer]
    def modifications_count
      changes_by_type(:modified).size
    end

    # Get count of additions
    # @return [Integer]
    def additions_count
      changes_by_type(:created).size
    end

    # Get count of deletions
    # @return [Integer]
    def deletions_count
      changes_by_type(:deleted).size
    end

    # Get array of changed file paths
    # @return [Array<String>]
    def changed_files
      @files.keys
    end

    # Get changes filtered by type
    # @param type [Symbol] The change type (:created, :modified, :deleted)
    # @return [Hash<String, Hash>] Filtered files hash
    def changes_by_type(type)
      unless CHANGE_TYPES.include?(type)
        raise ArgumentError, "Invalid change type: #{type}. Must be one of: #{CHANGE_TYPES.join(', ')}"
      end

      @files.select { |_path, details| details[:change_type] == type }
    end

    # Generate full unified diff across all files
    # @return [String] Combined diff string
    def full_diff
      @files.map do |path, details|
        header = "--- #{path}\n+++ #{path}\n"
        "#{header}#{details[:diff]}"
      end.join("\n\n")
    end

    # Get details for a specific file
    # @param path [String] The file path
    # @return [Hash, nil] The change details or nil if not found
    def file_details(path)
      @files[path]
    end

    # Check if a file was changed
    # @param path [String] The file path
    # @return [Boolean]
    def file_changed?(path)
      @files.key?(path)
    end

    # Check if any files were changed
    # @return [Boolean]
    def any_changes?
      @files.any?
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation
    def to_h
      {
        files: @files,
        checkpoint_id: @checkpoint_id,
        created_at: @created_at,
        milestone_id: @milestone_id,
        step_id: @step_id,
        summary: @summary
      }
    end

    # Reconstruct a ChangeSet from a hash
    # @param hash [Hash] Hash containing change set data
    # @return [Execution::ChangeSet] Reconstructed change set
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      new(
        files: hash[:files] || hash["files"] || {},
        checkpoint_id: hash[:checkpoint_id] || hash["checkpoint_id"],
        created_at: hash[:created_at] || hash["created_at"],
        milestone_id: hash[:milestone_id] || hash["milestone_id"],
        step_id: hash[:step_id] || hash["step_id"],
        summary: hash[:summary] || hash["summary"]
      )
    end

    private

    def validate_types!(files, checkpoint_id)
      raise ArgumentError, "files must be a Hash, got #{files.class}" unless files.is_a?(Hash)
      
      if checkpoint_id && !checkpoint_id.is_a?(String)
        raise ArgumentError, "checkpoint_id must be a String or nil, got #{checkpoint_id.class}"
      end
      
      if checkpoint_id && checkpoint_id.strip.empty?
        raise ArgumentError, "checkpoint_id cannot be empty"
      end
    end

    def validate_files_structure!(files)
      files.each do |path, details|
        unless path.is_a?(String)
          raise TypeError, "all file paths must be Strings, got #{path.class}"
        end

        unless details.is_a?(Hash)
          raise TypeError, "all file details must be Hashes, got #{details.class} for #{path}"
        end

        # Validate required keys
        unless details.key?(:change_type)
          raise ArgumentError, "file details for #{path} must include :change_type"
        end

        unless CHANGE_TYPES.include?(details[:change_type])
          raise ArgumentError, "invalid change_type for #{path}: #{details[:change_type]}. " \
                               "Must be one of: #{CHANGE_TYPES.join(', ')}"
        end

        unless details.key?(:diff)
          raise ArgumentError, "file details for #{path} must include :diff"
        end

        unless details[:diff].is_a?(String)
          raise TypeError, "diff for #{path} must be a String, got #{details[:diff].class}"
        end

        # Validate before_hash and after_hash if present
        if details.key?(:before_hash) && details[:before_hash] && !details[:before_hash].is_a?(String)
          raise TypeError, "before_hash for #{path} must be a String or nil, got #{details[:before_hash].class}"
        end

        if details.key?(:after_hash) && details[:after_hash] && !details[:after_hash].is_a?(String)
          raise TypeError, "after_hash for #{path} must be a String or nil, got #{details[:after_hash].class}"
        end
      end
    end
  end
end

