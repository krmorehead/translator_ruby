#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 5: Real-Time Progress Monitoring
#
# This example demonstrates how to monitor Sisyphus execution in real-time
# using the ExecutionProgressBroadcaster and Redis pub/sub.
#
# Note: In a web application, you would use Server-Sent Events (SSE) from
# the frontend. This example shows the backend equivalent.

require_relative "../config/environment"
require "redis"

puts "=" * 80
puts "Sisyphus Real-Time Monitoring Example"
puts "=" * 80
puts

# Configuration
PLAN_PATH = File.expand_path("plans/simple_hello_world.md", __dir__)
PROJECT_PATH = File.expand_path("projects/monitored_project", __dir__)

# Ensure project exists
unless Dir.exist?(PROJECT_PATH)
  puts "Creating project directory..."
  FileUtils.mkdir_p(PROJECT_PATH)
  Dir.chdir(PROJECT_PATH) do
    system("git init", out: File::NULL)
    system("git config user.email 'sisyphus@example.com'", out: File::NULL)
    system("git config user.name 'Sisyphus Agent'", out: File::NULL)
    File.write("README.md", "# Monitored Project\n")
    system("git add . && git commit -m 'Initial commit'", out: File::NULL)
  end
end

# Start execution
puts "Starting execution..."
service = ExecutionOrchestrationService.new
result = service.start_execution(
  plan_path: PLAN_PATH,
  project_path: PROJECT_PATH
)

unless result[:success]
  puts "❌ Failed to start: #{result[:error]}"
  exit 1
end

execution_id = result[:execution_id]
puts "✓ Execution started: #{execution_id}"
puts
puts "Monitoring progress (Ctrl+C to stop)..."
puts "=" * 80

# Subscribe to progress events
redis = Redis.current
channel = "worker:progress:#{execution_id}"

# Event statistics
stats = {
  total_events: 0,
  events_by_type: Hash.new(0),
  start_time: Time.now,
  files_changed: []
}

# Handle Ctrl+C gracefully
trap("INT") do
  puts "\n\nMonitoring stopped by user"
  print_stats(stats)
  exit 0
end

# Subscribe to progress channel
begin
  redis.subscribe(channel) do |on|
    on.message do |_channel, message|
      # Parse event
      event = JSON.parse(message, symbolize_names: true)
      
      # Update statistics
      stats[:total_events] += 1
      stats[:events_by_type][event[:event_type]] += 1
      
      # Display event
      timestamp = Time.now.strftime("%H:%M:%S.%L")
      event_type = event[:event_type]
      
      case event_type
      when :started
        puts "\n[#{timestamp}] 🚀 EXECUTION STARTED"
        puts "  Plan: #{event[:data][:plan_path]}"
        puts "  Project: #{event[:data][:project_path]}"
        
      when :milestone_started
        puts "\n[#{timestamp}] 📁 MILESTONE STARTED"
        puts "  ##{event[:data][:milestone_number]}: #{event[:data][:milestone_title]}"
        
      when :milestone_completed
        puts "\n[#{timestamp}] ✅ MILESTONE COMPLETED"
        puts "  ##{event[:data][:milestone_number]}"
        if event[:data][:checkpoint_id]
          puts "  Checkpoint: #{event[:data][:checkpoint_id][0..7]}"
        end
        
      when :step_started
        puts "\n[#{timestamp}] ⚙️  STEP STARTED"
        puts "  ##{event[:data][:step_number]}: #{event[:data][:step_title]}"
        
      when :step_completed
        puts "\n[#{timestamp}] ✓ STEP COMPLETED"
        puts "  ##{event[:data][:step_number]}"
        puts "  Progress: #{event[:data][:progress_percentage].round(1)}%"
        if event[:data][:files_changed]&.any?
          puts "  Files: #{event[:data][:files_changed].join(', ')}"
          stats[:files_changed].concat(event[:data][:files_changed])
        end
        
      when :step_failed
        puts "\n[#{timestamp}] ❌ STEP FAILED"
        puts "  ##{event[:data][:step_number]}"
        puts "  Error: #{event[:data][:error_message]}"
        
      when :file_changed
        puts "\n[#{timestamp}] 📝 FILE CHANGED"
        puts "  #{event[:data][:file_path]} (#{event[:data][:change_type]})"
        
      when :checkpoint_created
        puts "\n[#{timestamp}] 🔖 CHECKPOINT CREATED"
        puts "  ID: #{event[:data][:checkpoint_id][0..7]}"
        puts "  Message: #{event[:data][:message]}"
        
      when :approval_required
        puts "\n[#{timestamp}] ⏸️  APPROVAL REQUIRED"
        puts "  Type: #{event[:data][:type]}"
        puts "  Subject: #{event[:data][:subject_title]}"
        puts "  Approval ID: #{event[:data][:approval_id]}"
        puts "  Planned actions: #{event[:data][:planned_actions].size}"
        
      when :approval_approved
        puts "\n[#{timestamp}] ✓ APPROVED"
        puts "  Subject: #{event[:data][:subject_title]}"
        
      when :approval_rejected
        puts "\n[#{timestamp}] ✗ REJECTED"
        puts "  Subject: #{event[:data][:subject_title]}"
        
      when :approval_timeout
        puts "\n[#{timestamp}] ⏱️  APPROVAL TIMEOUT"
        puts "  Subject: #{event[:data][:subject_title]}"
        
      when :completed
        puts "\n[#{timestamp}] 🎉 EXECUTION COMPLETED"
        puts "  Steps: #{event[:data][:total_steps]}"
        puts "  Files changed: #{event[:data][:total_files_changed]}"
        print_stats(stats)
        break  # Stop monitoring
        
      when :failed
        puts "\n[#{timestamp}] 💥 EXECUTION FAILED"
        puts "  Error: #{event[:data][:error_message]}"
        print_stats(stats)
        break  # Stop monitoring
        
      when :cancelled
        puts "\n[#{timestamp}] 🛑 EXECUTION CANCELLED"
        print_stats(stats)
        break  # Stop monitoring
        
      else
        # Unknown event type
        puts "\n[#{timestamp}] 📨 #{event_type.to_s.upcase}"
        puts "  Data: #{event[:data].inspect}"
      end
    end
    
    on.subscribe do |_channel, _subscriptions|
      puts "✓ Subscribed to progress channel"
      puts
    end
  end
rescue Redis::BaseConnectionError => e
  puts "\n❌ Redis connection error: #{e.message}"
  puts "Make sure Redis is running: redis-server"
  exit 1
rescue StandardError => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

# Helper method to print statistics
def print_stats(stats)
  duration = Time.now - stats[:start_time]
  
  puts
  puts "=" * 80
  puts "MONITORING STATISTICS"
  puts "=" * 80
  puts "Duration: #{duration.round(1)}s"
  puts "Total Events: #{stats[:total_events]}"
  puts
  puts "Events by Type:"
  stats[:events_by_type].sort_by { |_k, v| -v }.each do |type, count|
    puts "  #{type.to_s.ljust(25)} #{count}"
  end
  
  if stats[:files_changed].any?
    puts
    puts "Files Changed (#{stats[:files_changed].uniq.size} unique):"
    stats[:files_changed].uniq.each do |file|
      puts "  - #{file}"
    end
  end
  puts "=" * 80
end

puts
puts "Monitoring example complete!"
puts

puts "Note: In a web application, use Server-Sent Events (SSE) instead:"
puts
puts "Frontend (JavaScript):"
puts "  import { subscribeToWorkerProgress } from './utils/workerProgressStream';"
puts "  "
puts "  const eventSource = subscribeToWorkerProgress({"
puts "    streamUrl: `/api/sisyphus/executions/${executionId}/stream`,"
puts "    onEvent: (event) => console.log(event),"
puts "    onComplete: (data) => console.log('Done!', data)"
puts "  });"
puts
puts "See: app/javascript/utils/workerProgressStream.js"
puts "     docs/architecture/streaming_progress.md"
puts








