# frozen_string_literal: true

# Policy for checkpoint creation decisions.
# Determines when checkpoints should be created based on configurable rules.
#
# @example Basic usage
#   policy = CheckpointPolicy.new(checkpoint_interval: 300)
#   if policy.should_checkpoint?(context)
#     # Create checkpoint
#   end
#
# @example With custom rules
#   policy = CheckpointPolicy.new(
#     checkpoint_interval: 600,
#     max_changes_before_checkpoint: 50
#   )
class CheckpointPolicy
  # Default configuration
  DEFAULT_CONFIG = {
    checkpoint_interval: 300,            # Seconds between automatic checkpoints
    max_changes_before_checkpoint: 100,  # Max file changes before forcing checkpoint
    checkpoint_on_milestone: true,       # Checkpoint at milestone boundaries
    checkpoint_on_error: false,          # Checkpoint before error recovery
    min_interval_between_checkpoints: 60 # Minimum seconds between checkpoints
  }.freeze

  attr_reader :config

  # Initialize the policy with configuration
  #
  # @param config [Hash] Policy configuration options
  def initialize(**config)
    @config = DEFAULT_CONFIG.merge(config)
    validate_config!
  end

  # Determine if a checkpoint should be created
  #
  # @param context [Hash] Context information for decision
  # @option context [Time] :last_checkpoint_time When last checkpoint was created
  # @option context [Integer] :files_changed Number of files changed since last checkpoint
  # @option context [Symbol] :trigger What triggered the check (:milestone, :error, :timer, :manual)
  # @option context [Hash] :metadata Additional context metadata
  # @return [Hash] Decision with :should_checkpoint boolean and :reason string
  def should_checkpoint?(context)
    validate_context!(context)
    
    trigger = context[:trigger] || :timer
    
    case trigger
    when :milestone
      handle_milestone_trigger(context)
    when :error
      handle_error_trigger(context)
    when :manual
      { should_checkpoint: true, reason: "Manual checkpoint requested" }
    when :timer
      handle_timer_trigger(context)
    else
      { should_checkpoint: false, reason: "Unknown trigger: #{trigger}" }
    end
  end

  # Check if interval-based checkpoint is due
  #
  # @param last_checkpoint_time [Time] When last checkpoint was created
  # @return [Boolean] True if checkpoint is due based on interval
  def interval_elapsed?(last_checkpoint_time)
    return true if last_checkpoint_time.nil?
    
    elapsed = Time.now.utc - last_checkpoint_time
    elapsed >= @config[:checkpoint_interval]
  end

  # Check if too many changes have accumulated
  #
  # @param files_changed [Integer] Number of files changed
  # @return [Boolean] True if checkpoint needed based on change count
  def too_many_changes?(files_changed)
    files_changed > @config[:max_changes_before_checkpoint]
  end

  # Check if minimum interval has passed since last checkpoint
  #
  # @param last_checkpoint_time [Time] When last checkpoint was created
  # @return [Boolean] True if minimum interval has passed
  def min_interval_passed?(last_checkpoint_time)
    return true if last_checkpoint_time.nil?
    
    elapsed = Time.now.utc - last_checkpoint_time
    elapsed >= @config[:min_interval_between_checkpoints]
  end

  # Update policy configuration
  #
  # @param new_config [Hash] Configuration options to update
  def update_config(**new_config)
    @config.merge!(new_config)
    validate_config!
  end

  private

  def validate_config!
    raise ArgumentError, "checkpoint_interval must be positive" unless @config[:checkpoint_interval] > 0
    raise ArgumentError, "max_changes_before_checkpoint must be positive" unless @config[:max_changes_before_checkpoint] > 0
    raise ArgumentError, "min_interval_between_checkpoints must be non-negative" unless @config[:min_interval_between_checkpoints] >= 0
    raise TypeError, "checkpoint_on_milestone must be boolean" unless [true, false].include?(@config[:checkpoint_on_milestone])
    raise TypeError, "checkpoint_on_error must be boolean" unless [true, false].include?(@config[:checkpoint_on_error])
  end

  def validate_context!(context)
    raise TypeError, "context must be a Hash" unless context.is_a?(Hash)
  end

  def handle_milestone_trigger(context)
    unless @config[:checkpoint_on_milestone]
      return { should_checkpoint: false, reason: "Milestone checkpoints disabled" }
    end
    
    last_checkpoint_time = context[:last_checkpoint_time]
    
    # Always checkpoint at milestones, unless minimum interval not met
    unless min_interval_passed?(last_checkpoint_time)
      return {
        should_checkpoint: false,
        reason: "Minimum interval not elapsed (#{@config[:min_interval_between_checkpoints]}s required)"
      }
    end
    
    { should_checkpoint: true, reason: "Milestone boundary reached" }
  end

  def handle_error_trigger(context)
    unless @config[:checkpoint_on_error]
      return { should_checkpoint: false, reason: "Error checkpoints disabled" }
    end
    
    last_checkpoint_time = context[:last_checkpoint_time]
    
    # Checkpoint before error recovery, unless minimum interval not met
    unless min_interval_passed?(last_checkpoint_time)
      return {
        should_checkpoint: false,
        reason: "Minimum interval not elapsed (#{@config[:min_interval_between_checkpoints]}s required)"
      }
    end
    
    { should_checkpoint: true, reason: "Checkpoint before error recovery" }
  end

  def handle_timer_trigger(context)
    last_checkpoint_time = context[:last_checkpoint_time]
    files_changed = context[:files_changed] || 0
    
    # Check if minimum interval has passed
    unless min_interval_passed?(last_checkpoint_time)
      return {
        should_checkpoint: false,
        reason: "Minimum interval not elapsed (#{@config[:min_interval_between_checkpoints]}s required)"
      }
    end
    
    # Check interval-based checkpoint
    if interval_elapsed?(last_checkpoint_time)
      return {
        should_checkpoint: true,
        reason: "Checkpoint interval elapsed (#{@config[:checkpoint_interval]}s)"
      }
    end
    
    # Check change-based checkpoint
    if too_many_changes?(files_changed)
      return {
        should_checkpoint: true,
        reason: "Too many changes accumulated (#{files_changed} files, limit: #{@config[:max_changes_before_checkpoint]})"
      }
    end
    
    { should_checkpoint: false, reason: "No checkpoint conditions met" }
  end
end

