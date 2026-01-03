#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 1: Basic Sisyphus Execution
#
# This example demonstrates the simplest way to use Sisyphus to autonomously
# execute a plan against a codebase.
#
# Prerequisites:
# - Ruby environment with all dependencies installed
# - Redis running (for state persistence)
# - LLM API keys configured in .env
# - A plan file (Markdown format)
# - A target codebase directory

require_relative "../config/environment"

# Configuration
PLAN_PATH = File.expand_path("../examples/plans/simple_hello_world.md", __dir__)
PROJECT_PATH = File.expand_path("../examples/projects/sample_project", __dir__)

puts "=" * 80
puts "Sisyphus Basic Execution Example"
puts "=" * 80
puts

puts "Plan: #{PLAN_PATH}"
puts "Project: #{PROJECT_PATH}"
puts

# Ensure directories exist
unless File.exist?(PLAN_PATH)
  puts "❌ Plan file not found: #{PLAN_PATH}"
  puts "Please create a plan file first."
  exit 1
end

unless Dir.exist?(PROJECT_PATH)
  puts "Creating project directory: #{PROJECT_PATH}"
  FileUtils.mkdir_p(PROJECT_PATH)
  
  # Initialize git repo in project
  Dir.chdir(PROJECT_PATH) do
    system("git init", out: File::NULL, err: File::NULL)
    system("git config user.email 'sisyphus@example.com'", out: File::NULL)
    system("git config user.name 'Sisyphus Agent'", out: File::NULL)
    
    # Create initial commit
    File.write("README.md", "# Sample Project\n")
    system("git add .", out: File::NULL)
    system("git commit -m 'Initial commit'", out: File::NULL)
  end
  puts "✓ Project initialized with git"
end

puts

# Step 1: Start execution via the orchestration service
puts "Step 1: Starting execution..."
puts "-" * 80

service = ExecutionOrchestrationService.new
result = service.start_execution(
  plan_path: PLAN_PATH,
  project_path: PROJECT_PATH,
  options: {
    approval_mode: :autonomous,  # No manual approval required
    dry_run: false               # Actually execute changes
  }
)

if result[:success]
  execution_id = result[:execution_id]
  puts "✓ Execution started successfully"
  puts "  Execution ID: #{execution_id}"
  puts "  Status: #{result[:state][:status]}"
else
  puts "❌ Failed to start execution: #{result[:error]}"
  exit 1
end

puts

# Step 2: Monitor execution progress
puts "Step 2: Monitoring execution progress..."
puts "-" * 80

# In a real application, you would:
# 1. Use SSE (Server-Sent Events) to receive real-time updates
# 2. Or poll the execution state periodically
#
# For this example, we'll poll the state every 2 seconds

max_wait_time = 300  # 5 minutes
start_time = Time.now
last_status = nil

loop do
  # Get current execution state
  state_result = service.get_execution_state(execution_id: execution_id)
  
  if state_result[:success]
    state = state_result[:state]
    current_status = state[:status]
    
    # Print status update if changed
    if current_status != last_status
      timestamp = Time.now.strftime("%H:%M:%S")
      puts "[#{timestamp}] Status: #{current_status}"
      
      if state[:current_milestone]
        puts "  Milestone: #{state[:current_milestone]}"
      end
      
      if state[:current_step]
        puts "  Step: #{state[:current_step]}"
      end
      
      if state[:progress_percentage]
        puts "  Progress: #{state[:progress_percentage].round(1)}%"
      end
      
      if state[:files_changed]&.any?
        puts "  Files changed: #{state[:files_changed].size}"
      end
      
      last_status = current_status
    end
    
    # Check if execution is complete
    if %i[complete failed].include?(current_status)
      puts
      puts "Execution finished: #{current_status}"
      
      if current_status == :complete
        puts "✓ Execution completed successfully!"
        puts
        puts "Results:"
        puts "  Files changed: #{state[:files_changed]&.size || 0}"
        puts "  Checkpoints created: #{state[:checkpoint_ids]&.size || 0}"
        puts "  Duration: #{(Time.now - start_time).round(1)}s"
      else
        puts "❌ Execution failed"
        if state[:error]
          puts "  Error: #{state[:error]}"
        end
      end
      
      break
    end
  else
    puts "❌ Failed to get execution state: #{state_result[:error]}"
    break
  end
  
  # Check timeout
  if Time.now - start_time > max_wait_time
    puts "⏱️ Timeout: Execution took longer than #{max_wait_time} seconds"
    puts "Execution may still be running in the background."
    break
  end
  
  # Wait before next poll
  sleep 2
end

puts
puts "=" * 80
puts "Example complete!"
puts "=" * 80
puts
puts "Next steps:"
puts "1. Check the project directory for changes: #{PROJECT_PATH}"
puts "2. Review git log to see checkpoints"
puts "3. Try the approval mode example: examples/03_approval_mode.rb"
puts

