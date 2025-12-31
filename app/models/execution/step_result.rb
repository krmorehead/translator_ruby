# frozen_string_literal: true

module Execution
  # Represents the result of executing a single plan step.
  # Captures all actions taken, files changed, diffs generated, and tool outputs.
  #
  # @example Creating a step result
  #   result = Execution::StepResult.new(
  #     step_id: "1.1",
  #     success: true,
  #     actions_taken: [action1, action2],
  #     files_changed: ["app/models/user.rb"],
  #     diffs: { "app/models/user.rb" => "+class User\n+end" }
  #   )
  #
  # @example With evaluation result
  #   result = Execution::StepResult.new(
  #     step_id: "1.1",
  #     success: true,
  #     actions_taken: [],
  #     files_changed: [],
  #     diffs: {},
  #     evaluation_result: {
  #       passed: true,
  #       confidence: 0.95,
  #       feedback: "All requirements met"
  #     }
  #   )
  class StepResult
    attr_reader :step_id, :success, :actions_taken, :files_changed, :diffs,
                :tool_outputs, :error_message, :duration, :executed_at,
                :evaluation_result, :validation_warnings

    # @param step_id [String] The step identifier (e.g., "1.1")
    # @param success [Boolean] Whether the step executed successfully
    # @param actions_taken [Array<ActionRecord>] Actions executed during the step
    # @param files_changed [Array<String>] Paths of files that were modified
    # @param diffs [Hash<String, String>] Map of file path to diff string
    # @param tool_outputs [Hash] Optional tool execution outputs
    # @param error_message [String, nil] Optional error message if failed
    # @param duration [Float, nil] Optional execution duration in seconds
    # @param executed_at [String, nil] Optional ISO8601 timestamp
    # @param evaluation_result [Hash, nil] Optional evaluation result from StepEvaluationWorkflow
    # @param validation_warnings [Array<String>] Optional validation warnings
    def initialize(step_id:, success:, actions_taken:, files_changed:, diffs:,
                   tool_outputs: {}, error_message: nil, duration: nil, executed_at: nil,
                   evaluation_result: nil, validation_warnings: [])
      validate_types!(step_id, success, actions_taken, files_changed, diffs,
                      tool_outputs, validation_warnings)
      
      @step_id = step_id
      @success = success
      @actions_taken = Array(actions_taken)
      @files_changed = Array(files_changed)
      @diffs = diffs
      @tool_outputs = tool_outputs
      @error_message = error_message
      @duration = duration
      @executed_at = executed_at || Time.now.utc.iso8601
      @evaluation_result = evaluation_result
      @validation_warnings = Array(validation_warnings)
    end

    # Check if the step was successful
    # @return [Boolean]
    def successful?
      @success == true
    end

    # Check if the step failed
    # @return [Boolean]
    def failed?
      !successful?
    end

    # Get the count of files changed
    # @return [Integer]
    def file_count
      @files_changed.size
    end

    # Get the count of actions taken
    # @return [Integer]
    def action_count
      @actions_taken.size
    end

    # Check if there are any diffs
    # @return [Boolean]
    def has_diffs?
      @diffs.any?
    end

    # Get diff for a specific file
    # @param file_path [String] Path to the file
    # @return [String, nil] The diff string or nil if not found
    def diff_for(file_path)
      @diffs[file_path]
    end

    # Generate a formatted summary of the step result
    # @return [String] Human-readable summary
    def formatted_summary
      status = successful? ? "SUCCESS" : "FAILED"
      summary = ["Step #{@step_id}: #{status}"]
      
      if successful?
        summary << "  Actions: #{action_count}"
        summary << "  Files changed: #{file_count}"
        summary << "  Duration: #{@duration&.round(2)}s" if @duration
        
        if @evaluation_result
          summary << "  Evaluation: #{@evaluation_result[:passed] ? 'PASSED' : 'FAILED'}"
          summary << "  Confidence: #{@evaluation_result[:confidence]}" if @evaluation_result[:confidence]
        end
      else
        summary << "  Error: #{@error_message}"
      end

      if @validation_warnings.any?
        summary << "  Warnings: #{@validation_warnings.size}"
      end

      summary.join("\n")
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation including all actions and diffs
    def to_h
      {
        step_id: @step_id,
        success: @success,
        actions_taken: @actions_taken.map { |a| action_to_h(a) },
        files_changed: @files_changed,
        diffs: @diffs,
        tool_outputs: @tool_outputs,
        error_message: @error_message,
        duration: @duration,
        executed_at: @executed_at,
        evaluation_result: @evaluation_result,
        validation_warnings: @validation_warnings
      }
    end

    # Reconstruct a StepResult from a hash
    # @param hash [Hash] Hash containing step result data
    # @return [Execution::StepResult] Reconstructed step result
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      # Reconstruct actions (for now, just store as hashes since ActionRecord might not exist yet)
      actions = hash[:actions_taken] || hash["actions_taken"] || []
      
      new(
        step_id: hash[:step_id] || hash["step_id"],
        success: hash[:success] || hash["success"],
        actions_taken: actions,
        files_changed: hash[:files_changed] || hash["files_changed"] || [],
        diffs: hash[:diffs] || hash["diffs"] || {},
        tool_outputs: hash[:tool_outputs] || hash["tool_outputs"] || {},
        error_message: hash[:error_message] || hash["error_message"],
        duration: hash[:duration] || hash["duration"],
        executed_at: hash[:executed_at] || hash["executed_at"],
        evaluation_result: hash[:evaluation_result] || hash["evaluation_result"],
        validation_warnings: hash[:validation_warnings] || hash["validation_warnings"] || []
      )
    end

    private

    def validate_types!(step_id, success, actions_taken, files_changed, diffs,
                        tool_outputs, validation_warnings)
      raise ArgumentError, "step_id must be a String, got #{step_id.class}" unless step_id.is_a?(String)
      raise ArgumentError, "step_id cannot be empty" if step_id.strip.empty?
      
      unless [true, false].include?(success)
        raise ArgumentError, "success must be a Boolean, got #{success.class}"
      end
      
      raise ArgumentError, "actions_taken must be an Array, got #{actions_taken.class}" unless actions_taken.is_a?(Array)
      raise ArgumentError, "files_changed must be an Array, got #{files_changed.class}" unless files_changed.is_a?(Array)
      
      # Validate files_changed contains only strings
      if files_changed.any? { |f| !f.is_a?(String) }
        raise TypeError, "all files_changed must be Strings"
      end
      
      raise ArgumentError, "diffs must be a Hash, got #{diffs.class}" unless diffs.is_a?(Hash)
      
      # Validate diffs keys and values are strings
      diffs.each do |key, value|
        unless key.is_a?(String)
          raise TypeError, "all diff keys must be Strings, got #{key.class}"
        end
        unless value.is_a?(String)
          raise TypeError, "all diff values must be Strings, got #{value.class}"
        end
      end
      
      raise ArgumentError, "tool_outputs must be a Hash, got #{tool_outputs.class}" unless tool_outputs.is_a?(Hash)
      raise ArgumentError, "validation_warnings must be an Array, got #{validation_warnings.class}" unless validation_warnings.is_a?(Array)
    end

    # Convert action to hash (handles both ActionRecord objects and hashes)
    def action_to_h(action)
      return action.to_h if action.respond_to?(:to_h)
      action
    end
  end
end

