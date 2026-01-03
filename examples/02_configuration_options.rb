#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 2: Configuration Options
#
# This example demonstrates the various configuration options available
# for Sisyphus execution, including approval modes, dry-run, and error handling.

require_relative "../config/environment"

puts "=" * 80
puts "Sisyphus Configuration Examples"
puts "=" * 80
puts

# Example 1: Autonomous Mode (Default)
# No approvals required, execution runs completely automatically
puts "Configuration 1: Autonomous Mode (Default)"
puts "-" * 80

autonomous_config = Configuration::SisyphusConfig.new(
  approval_mode: :autonomous,    # No manual approval
  max_retries: 3,                # Retry failed steps up to 3 times
  stream_progress: true,         # Enable real-time progress streaming
  error_mode: :fail_fast,        # Stop on first error
  dry_run: false                 # Actually execute changes
)

puts "Approval Mode: #{autonomous_config.approval_mode}"
puts "Max Retries: #{autonomous_config.max_retries}"
puts "Stream Progress: #{autonomous_config.stream_progress?}"
puts "Error Mode: #{autonomous_config.error_mode}"
puts "Dry Run: #{autonomous_config.dry_run?}"
puts
puts "Use case: Fully automated execution in CI/CD pipelines or"
puts "          trusted environments where human oversight isn't needed."
puts

# Example 2: Step Approval Mode
# Requires approval before executing each individual step
puts "Configuration 2: Step Approval Mode"
puts "-" * 80

step_approval_config = Configuration::SisyphusConfig.new(
  approval_mode: :step,          # Approve each step
  max_retries: 2,
  stream_progress: true,
  error_mode: :continue,         # Continue after errors
  dry_run: false
)

puts "Approval Mode: #{step_approval_config.approval_mode}"
puts "Max Retries: #{step_approval_config.max_retries}"
puts "Error Mode: #{step_approval_config.error_mode}"
puts
puts "Use case: Maximum control and oversight. Best for:"
puts "          - Critical production changes"
puts "          - Learning/exploration mode"
puts "          - Untrusted or experimental plans"
puts
puts "Workflow:"
puts "  1. Sisyphus plans the step"
puts "  2. Shows planned actions and file changes"
puts "  3. Waits for user approval"
puts "  4. Executes only if approved"
puts

# Example 3: Milestone Approval Mode
# Requires approval before executing each milestone (group of steps)
puts "Configuration 3: Milestone Approval Mode"
puts "-" * 80

milestone_approval_config = Configuration::SisyphusConfig.new(
  approval_mode: :milestone,     # Approve each milestone
  max_retries: 3,
  stream_progress: true,
  error_mode: :fail_fast,
  dry_run: false
)

puts "Approval Mode: #{milestone_approval_config.approval_mode}"
puts
puts "Use case: Balanced control vs. automation. Best for:"
puts "          - Staged deployments"
puts "          - Multi-phase migrations"
puts "          - Complex refactoring with logical checkpoints"
puts
puts "Workflow:"
puts "  1. Sisyphus shows all steps in the milestone"
puts "  2. Shows cumulative planned changes"
puts "  3. Waits for user approval"
puts "  4. Executes entire milestone if approved"
puts

# Example 4: Dry-Run Mode
# Simulates execution without making actual changes
puts "Configuration 4: Dry-Run Mode"
puts "-" * 80

dry_run_config = Configuration::SisyphusConfig.new(
  approval_mode: :autonomous,
  max_retries: 1,
  stream_progress: true,
  error_mode: :fail_fast,
  dry_run: true                  # Simulate changes only
)

puts "Approval Mode: #{dry_run_config.approval_mode}"
puts "Dry Run: #{dry_run_config.dry_run?}"
puts
puts "Use case: Preview execution without making changes. Best for:"
puts "          - Testing new plans"
puts "          - Previewing what Sisyphus will do"
puts "          - Generating diffs for review"
puts
puts "Behavior:"
puts "  - LLM planning executes normally"
puts "  - Tool calls are simulated (not executed)"
puts "  - Diffs show expected changes"
puts "  - No actual files are modified"
puts

# Example 5: Custom Configuration for CI/CD
puts "Configuration 5: CI/CD Pipeline Configuration"
puts "-" * 80

cicd_config = Configuration::SisyphusConfig.new(
  approval_mode: :autonomous,    # Fully automated
  max_retries: 2,                # Limited retries
  stream_progress: true,         # Stream to CI logs
  error_mode: :fail_fast,        # Stop immediately on error
  dry_run: false
)

puts "Approval Mode: #{cicd_config.approval_mode}"
puts "Max Retries: #{cicd_config.max_retries}"
puts "Error Mode: #{cicd_config.error_mode}"
puts
puts "Use case: Automated execution in CI/CD. Best for:"
puts "          - Automated code generation"
puts "          - Scheduled maintenance tasks"
puts "          - Automated migrations"
puts
puts "Pipeline example:"
puts "  ```yaml"
puts "  sisyphus:"
puts "    runs-on: ubuntu-latest"
puts "    steps:"
puts "      - uses: actions/checkout@v2"
puts "      - name: Run Sisyphus"
puts "        run: |"
puts "          bundle exec ruby -e '"
puts "          service = ExecutionOrchestrationService.new"
puts "          result = service.start_execution("
puts "            plan_path: 'plans/migration.md',"
puts "            project_path: '.',"
puts "            options: { approval_mode: :autonomous }"
puts "          )"
puts "          exit 1 unless result[:success]"
puts "          '"
puts "  ```"
puts

# Example 6: Development/Learning Configuration
puts "Configuration 6: Development/Learning Mode"
puts "-" * 80

learning_config = Configuration::SisyphusConfig.new(
  approval_mode: :step,          # Review every step
  max_retries: 3,                # More retries for experimentation
  stream_progress: true,
  error_mode: :continue,         # Keep going after errors
  dry_run: false
)

puts "Approval Mode: #{learning_config.approval_mode}"
puts "Max Retries: #{learning_config.max_retries}"
puts "Error Mode: #{learning_config.error_mode}"
puts
puts "Use case: Learning how Sisyphus works. Best for:"
puts "          - Understanding Sisyphus behavior"
puts "          - Debugging plans"
puts "          - Experimenting with prompts"
puts

# Configuration Serialization
puts "=" * 80
puts "Configuration Serialization"
puts "=" * 80
puts
puts "All configurations can be serialized to/from hashes:"
puts

serialized = autonomous_config.to_h
puts "Serialized:"
puts serialized.inspect
puts

# Can be stored, transmitted, or loaded from files
require "json"
puts "As JSON:"
puts JSON.pretty_generate(serialized)
puts

puts "=" * 80
puts "Summary: Choosing the Right Configuration"
puts "=" * 80
puts
puts "┌────────────────┬──────────────┬──────────────┬─────────────────────┐"
puts "│ Scenario       │ Approval     │ Error Mode   │ Dry Run             │"
puts "├────────────────┼──────────────┼──────────────┼─────────────────────┤"
puts "│ CI/CD Pipeline │ autonomous   │ fail_fast    │ false               │"
puts "│ Production     │ milestone    │ fail_fast    │ false               │"
puts "│ Experimentation│ step         │ continue     │ true (preview first)│"
puts "│ Learning       │ step         │ continue     │ false               │"
puts "│ Preview        │ autonomous   │ fail_fast    │ true                │"
puts "└────────────────┴──────────────┴──────────────┴─────────────────────┘"
puts
puts "For more examples:"
puts "- Basic execution: examples/01_basic_execution.rb"
puts "- Approval mode: examples/03_approval_mode.rb"
puts "- API usage: examples/04_api_usage.rb"
puts


