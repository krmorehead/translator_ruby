#!/usr/bin/env ruby

# Set test environment
ENV["RAILS_ENV"] = "test"

# Parse command line arguments for speed profile
def parse_speed_flag(args)
  speed_index = args.index("--speed")
  
  if speed_index.nil?
    puts "Error: --speed flag is required"
    puts ""
    puts "Usage: ruby lib/test_runner.rb --speed LEVEL [test_options]"
    puts ""
    puts "Speed levels:"
    puts "  fast   - Run only fast tests (<10s each)"
    puts "  medium - Run fast and medium tests (<60s each)"
    puts "  slow   - Run all tests including slow ones (<120s each)"
    puts "  all    - Run all tests regardless of speed profile"
    puts ""
    puts "Examples:"
    puts "  ruby lib/test_runner.rb --speed fast"
    puts "  ruby lib/test_runner.rb --speed medium test/models"
    puts "  ruby lib/test_runner.rb --speed all test/services/translation_service_test.rb"
    exit 1
  end
  
  speed_value = args[speed_index + 1]
  
  unless %w[fast medium slow all].include?(speed_value)
    puts "Error: Invalid speed level '#{speed_value}'"
    puts "Valid levels: fast, medium, slow, all"
    exit 1
  end
  
  # Remove --speed and its value from args
  args.delete_at(speed_index + 1)
  args.delete_at(speed_index)
  
  speed_value
end

# Parse and set speed filter
speed_level = parse_speed_flag(ARGV)
ENV["TEST_SPEED_FILTER"] = speed_level

puts "Running tests with speed filter: #{speed_level}"
puts ""

# Run the tests with remaining arguments
exec "bundle", "exec", "rails", "test", *ARGV

