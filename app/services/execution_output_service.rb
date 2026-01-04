# frozen_string_literal: true

# Service for writing comprehensive execution logs with diffs, checkpoints, and metadata.
# Creates a directory structure with multiple output files documenting execution.
#
# @example Basic usage
#   service = ExecutionOutputService.new
#   result = service.write_execution_output(execution_record, plan_name: "my_plan")
#   puts "Logs written to: #{result[:output_dir]}"
#
# @example With options
#   result = service.write_execution_output(
#     execution_record,
#     plan_name: "my_plan",
#     include_diffs: true,
#     include_checkpoints: true
#   )
class ExecutionOutputService
  attr_reader :base_path, :options

  DEFAULT_BASE_PATH = ".agents/docs/executions"
  DEFAULT_OPTIONS = {
    include_diffs: true,
    include_checkpoints: true
  }.freeze

  # Initialize the output service
  #
  # @param base_path [String] Base directory for execution logs (optional, defaults to AgentConfig.data_path)
  # @param options [Hash] Additional options
  def initialize(base_path: nil, **options)
    @base_path = base_path || File.join(AgentConfig.data_path, DEFAULT_BASE_PATH)
    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Write complete execution output to files
  #
  # @param execution_record [Execution::ExecutionRecord] The execution record to write
  # @param plan_name [String, nil] Optional plan name for directory
  # @param include_diffs [Boolean] Whether to write individual diff files
  # @param include_checkpoints [Boolean] Whether to write checkpoints file
  # @return [Hash] Hash with paths to all created files
  # @raise [ArgumentError] If execution_record is nil
  # @raise [TypeError] If execution_record is not an ExecutionRecord
  # @raise [RuntimeError] If file system operations fail
  def write_execution_output(execution_record, plan_name: nil, include_diffs: true, include_checkpoints: true)
    validate_params!(execution_record)
    
    # Create output directory
    output_dir = create_output_directory(execution_record, plan_name)
    
    # Write all output files
    result = {
      output_dir: output_dir,
      log_file: write_execution_log(output_dir, execution_record),
      json_file: write_execution_json(output_dir, execution_record),
      changes_file: write_changes_file(output_dir, execution_record),
      metadata_file: write_metadata_file(output_dir, execution_record)
    }
    
    # Optional files based on options
    if include_diffs
      result[:diffs_dir] = write_diffs(output_dir, execution_record)
    end
    
    if include_checkpoints && !execution_record.checkpoint_ids.empty?
      result[:checkpoints_file] = write_checkpoints_file(output_dir, execution_record)
    end
    
    result
  rescue Errno::EACCES, Errno::ENOENT => e
    raise RuntimeError, "Failed to write execution output: #{e.message}"
  end

  private

  def validate_params!(execution_record)
    raise ArgumentError, "execution_record is required" if execution_record.nil?
    raise TypeError, "execution_record must be an Execution::ExecutionRecord, got #{execution_record.class}" unless execution_record.is_a?(Execution::ExecutionRecord)
  end

  def create_output_directory(execution_record, plan_name)
    # Generate directory name with timestamp
    started_time = Time.parse(execution_record.started_at)
    timestamp = started_time.strftime("%Y%m%d_%H%M%S")
    sanitized_name = sanitize_plan_name(plan_name || "execution_#{timestamp}")
    
    dir_name = "#{timestamp}_#{sanitized_name}"
    output_dir = File.join(@base_path, dir_name)
    
    FileUtils.mkdir_p(output_dir)
    output_dir
  end

  def sanitize_plan_name(name)
    # Remove or replace characters not safe for file systems
    name.gsub(/[\/\\:*?"<>|]/, "_").gsub(/\s+/, "_")
  end

  def write_execution_log(output_dir, record)
    log_file = File.join(output_dir, "execution_log.md")
    
    content = build_execution_log_content(record)
    File.write(log_file, content)
    
    log_file
  end

  def build_execution_log_content(record)
    lines = []
    lines << "# Execution Log"
    lines << ""
    lines << "**Plan ID**: #{record.plan_id}"
    lines << "**Status**: #{record.status}"
    lines << "**Started**: #{record.started_at}"
    lines << "**Completed**: #{record.completed_at || 'N/A'}"
    lines << "**Duration**: #{format_duration(record.duration)}"
    lines << ""
    
    # Progress summary
    lines << "## Progress Summary"
    lines << ""
    lines << "- **Total Steps**: #{record.total_steps}"
    lines << "- **Completed**: #{record.completed_steps}"
    lines << "- **Failed**: #{record.failed_steps}"
    lines << "- **Progress**: #{record.progress_percentage.round(1)}%"
    lines << ""
    
    # Step results
    lines << "## Step Results"
    lines << ""
    
    record.step_results.each_with_index do |step_result, idx|
      lines << "### Step #{idx + 1}: #{step_result.step_id}"
      lines << ""
      lines << "- **Status**: #{step_result.success ? '✓ Success' : '✗ Failed'}"
      lines << "- **Duration**: #{format_duration(step_result.duration)}"
      lines << "- **Files Changed**: #{step_result.files_changed.size}"
      lines << "- **Actions Taken**: #{step_result.actions_taken.size}"
      
      if step_result.error_message
        lines << "- **Error**: #{step_result.error_message}"
      end
      
      lines << ""
    end
    
    # Files changed
    if record.total_files_changed > 0
      lines << "## Files Changed"
      lines << ""
      
      all_files = record.step_results.flat_map(&:files_changed).uniq
      all_files.each do |file|
        lines << "- `#{file}`"
      end
      lines << ""
    end
    
    # Checkpoints
    unless record.checkpoint_ids.empty?
      lines << "## Checkpoints"
      lines << ""
      record.checkpoint_ids.each do |checkpoint_id|
        lines << "- `#{checkpoint_id}`"
      end
      lines << ""
    end
    
    lines.join("\n")
  end

  def write_execution_json(output_dir, record)
    json_file = File.join(output_dir, "execution.json")
    
    json_content = JSON.pretty_generate(record.to_h)
    File.write(json_file, json_content)
    
    json_file
  end

  def write_changes_file(output_dir, record)
    changes_file = File.join(output_dir, "changes.md")
    
    content = build_changes_content(record)
    File.write(changes_file, content)
    
    changes_file
  end

  def build_changes_content(record)
    lines = []
    lines << "# File Changes"
    lines << ""
    lines << "Summary of all file modifications during execution."
    lines << ""
    
    # Group changes by file
    file_changes = {}
    
    record.step_results.each do |step_result|
      step_result.files_changed.each do |file|
        file_changes[file] ||= []
        file_changes[file] << {
          step_id: step_result.step_id,
          diff: step_result.diff_for(file)
        }
      end
    end
    
    file_changes.each do |file, changes|
      lines << "## #{file}"
      lines << ""
      lines << "Modified in #{changes.size} step(s)"
      lines << ""
      
      changes.each do |change|
        lines << "### Step: #{change[:step_id]}"
        lines << ""
        
        if change[:diff]
          # Include first 20 lines of diff
          diff_lines = change[:diff].split("\n")[0...20]
          lines << "```diff"
          lines.concat(diff_lines)
          if change[:diff].split("\n").size > 20
            lines << "... (truncated)"
          end
          lines << "```"
        end
        
        lines << ""
      end
    end
    
    lines.join("\n")
  end

  def write_diffs(output_dir, record)
    diffs_dir = File.join(output_dir, "diffs")
    FileUtils.mkdir_p(diffs_dir)
    
    # Write individual diff files
    record.step_results.each do |step_result|
      step_result.diffs.each do |file_path, diff|
        # Sanitize file path for filename
        safe_filename = file_path.gsub("/", "_").gsub(/[^a-zA-Z0-9_.-]/, "_")
        diff_file = File.join(diffs_dir, "#{safe_filename}.diff")
        
        File.write(diff_file, diff)
      end
    end
    
    diffs_dir
  end

  def write_checkpoints_file(output_dir, record)
    checkpoints_file = File.join(output_dir, "checkpoints.md")
    
    return checkpoints_file if record.checkpoint_ids.empty?
    
    content = build_checkpoints_content(record)
    File.write(checkpoints_file, content)
    
    checkpoints_file
  end

  def build_checkpoints_content(record)
    lines = []
    lines << "# Checkpoints"
    lines << ""
    lines << "Git checkpoints created during execution."
    lines << ""
    
    record.checkpoint_ids.each_with_index do |checkpoint_id, idx|
      lines << "## Checkpoint #{idx + 1}"
      lines << ""
      lines << "**ID**: `#{checkpoint_id}`"
      lines << ""
      lines << "### Rollback Command"
      lines << ""
      lines << "```bash"
      lines << "git reset --hard #{checkpoint_id}"
      lines << "```"
      lines << ""
    end
    
    lines.join("\n")
  end

  def write_metadata_file(output_dir, record)
    metadata_file = File.join(output_dir, "metadata.json")
    
    metadata = {
      plan_id: record.plan_id,
      started_at: record.started_at,
      completed_at: record.completed_at,
      duration: record.duration,
      status: record.status,
      checkpoint_ids: record.checkpoint_ids,
      total_steps: record.total_steps,
      completed_steps: record.completed_steps,
      failed_steps: record.failed_steps,
      total_files_changed: record.total_files_changed
    }
    
    json_content = JSON.pretty_generate(metadata)
    File.write(metadata_file, json_content)
    
    metadata_file
  end

  def format_duration(seconds)
    return "N/A" if seconds.nil?
    
    if seconds < 60
      "#{seconds.round(1)}s"
    elsif seconds < 3600
      "#{(seconds / 60).round(1)}m"
    else
      hours = (seconds / 3600).floor
      minutes = ((seconds % 3600) / 60).round
      "#{hours}h #{minutes}m"
    end
  end
end

