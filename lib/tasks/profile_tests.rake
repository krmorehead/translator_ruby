# frozen_string_literal: true

namespace :test do
  desc "Profile all tests and generate speed profile recommendations"
  task profile: :environment do
    puts "=" * 80
    puts "Test Speed Profiling - Analyzing all tests"
    puts "=" * 80
    puts ""

    # Collect all test files
    test_files = Dir[Rails.root.join("test/**/*_test.rb")].sort
    
    results = []
    total_tests = test_files.size
    current = 0
    
    test_files.each do |test_file|
      current += 1
      relative_path = test_file.sub("#{Rails.root}/", "")
      
      print "\r[#{current}/#{total_tests}] Profiling #{relative_path}...".ljust(100)
      
      # Run the test file and capture timing
      # Set SKIP_SPEED_PROFILE_VALIDATION to avoid errors during profiling
      start_time = Time.now
      output = `SKIP_SPEED_PROFILE_VALIDATION=true bundle exec rails test #{test_file} 2>&1`
      end_time = Time.now
      duration = end_time - start_time
      exit_status = $?.exitstatus
      
      # Parse test counts from output
      if output =~ /(\d+) runs, (\d+) assertions/
        test_count = $1.to_i
        
        # Calculate average time per test if multiple tests in file
        avg_time = test_count > 0 ? duration / test_count : duration
        
        # Determine suggested speed profile
        suggested_profile = if avg_time < 10
          :fast
        elsif avg_time < 60
          :medium
        else
          :slow
        end
        
        results << {
          file: relative_path,
          total_duration: duration,
          test_count: test_count,
          avg_duration: avg_time,
          suggested_profile: suggested_profile,
          exit_status: exit_status
        }
      else
        # File might have no tests or failed to run
        results << {
          file: relative_path,
          total_duration: duration,
          test_count: 0,
          avg_duration: 0,
          suggested_profile: :fast,  # Default for empty files
          exit_status: exit_status,
          error: true
        }
      end
    end
    
    puts "\r" + " " * 100 + "\r"  # Clear progress line
    puts ""
    puts "=" * 80
    puts "Summary"
    puts "=" * 80
    
    # Group by suggested profile
    fast_tests = results.select { |r| r[:suggested_profile] == :fast && !r[:error] }
    medium_tests = results.select { |r| r[:suggested_profile] == :medium }
    slow_tests = results.select { |r| r[:suggested_profile] == :slow }
    error_tests = results.select { |r| r[:error] }
    
    puts ""
    puts "FAST tests (<10s): #{fast_tests.size} files"
    puts "MEDIUM tests (<60s): #{medium_tests.size} files"
    puts "SLOW tests (≥60s): #{slow_tests.size} files"
    puts "ERROR/NO TESTS: #{error_tests.size} files"
    puts ""
    
    # Generate report file
    report_path = Rails.root.join("tmp/test_speed_profile_report.txt")
    FileUtils.mkdir_p(File.dirname(report_path))
    
    File.open(report_path, "w") do |f|
      f.puts "Test Speed Profile Report"
      f.puts "Generated: #{Time.now}"
      f.puts "=" * 80
      f.puts ""
      
      f.puts "FAST Tests (<10s):"
      f.puts "-" * 80
      fast_tests.sort_by { |r| r[:avg_duration] }.reverse.each do |r|
        f.puts "#{r[:file]}"
        f.puts "  Total: #{r[:total_duration].round(2)}s | Tests: #{r[:test_count]} | Avg: #{r[:avg_duration].round(2)}s"
        f.puts "  Add: speed_profile :fast"
        f.puts ""
      end
      
      f.puts ""
      f.puts "MEDIUM Tests (<60s):"
      f.puts "-" * 80
      medium_tests.sort_by { |r| r[:avg_duration] }.reverse.each do |r|
        f.puts "#{r[:file]}"
        f.puts "  Total: #{r[:total_duration].round(2)}s | Tests: #{r[:test_count]} | Avg: #{r[:avg_duration].round(2)}s"
        f.puts "  Add: speed_profile :medium"
        f.puts ""
      end
      
      f.puts ""
      f.puts "SLOW Tests (≥60s):"
      f.puts "-" * 80
      slow_tests.sort_by { |r| r[:avg_duration] }.reverse.each do |r|
        f.puts "#{r[:file]}"
        f.puts "  Total: #{r[:total_duration].round(2)}s | Tests: #{r[:test_count]} | Avg: #{r[:avg_duration].round(2)}s"
        f.puts "  Add: speed_profile :slow"
        f.puts ""
      end
      
      if error_tests.any?
        f.puts ""
        f.puts "ERROR/NO TESTS:"
        f.puts "-" * 80
        error_tests.each do |r|
          f.puts "#{r[:file]} (exit: #{r[:exit_status]})"
        end
        f.puts ""
      end
      
      f.puts ""
      f.puts "=" * 80
      f.puts "Summary Statistics"
      f.puts "=" * 80
      f.puts "Total test files: #{results.size}"
      f.puts "Fast: #{fast_tests.size} (#{(fast_tests.size.to_f / results.size * 100).round(1)}%)"
      f.puts "Medium: #{medium_tests.size} (#{(medium_tests.size.to_f / results.size * 100).round(1)}%)"
      f.puts "Slow: #{slow_tests.size} (#{(slow_tests.size.to_f / results.size * 100).round(1)}%)"
      f.puts ""
      valid_results = results.reject { |r| r[:error] }
      f.puts "Total test time: #{valid_results.sum { |r| r[:total_duration] }.round(2)}s"
      f.puts "Average per file: #{(valid_results.sum { |r| r[:total_duration] } / valid_results.size).round(2)}s" if valid_results.any?
    end
    
    puts "Detailed report saved to: #{report_path}"
    puts ""
    puts "=" * 80
    puts "Next Steps:"
    puts "1. Review the report at #{report_path}"
    puts "2. Add speed_profile declarations to test files"
    puts "3. Run tests with: ruby lib/test_runner.rb --speed fast"
    puts "=" * 80
  end
end
