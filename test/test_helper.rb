ENV["RAILS_ENV"] ||= "test"

# Load test environment variables from .env.test
require "dotenv"
Dotenv.load(".env.test")

require_relative "../config/environment"
require "rails/test_help"
require "minitest/spec"

# Enable logging in tests for debugging
Rails.logger.level = Logger::DEBUG
Rails.logger = Logger.new($stdout) if ENV["VERBOSE_TESTS"]

# Load support files
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Enable Minitest::Spec DSL (let, before, etc.)
    extend Minitest::Spec::DSL

    # Run tests in parallel with specified workers
    # Threshold of 50 means small test runs execute in single process
    # This allows class-level caching for LLM-heavy tests to work
    parallelize(workers: :number_of_processors, threshold: 50)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include FactoryBot methods
    include FactoryBot::Syntax::Methods

    # Include SpeedProfile module for test speed enforcement
    include SpeedProfile unless ENV["SKIP_SPEED_PROFILE_VALIDATION"] == "true"


    # Helper to create a temporary directory initialized as a Git repository
    # @return [String] Path to the temporary Git repository
    def create_temp_git_repo
      dir = Dir.mktmpdir
      Dir.chdir(dir) do
        system("git init", out: File::NULL, err: File::NULL)
        system("git config user.email 'test@example.com'", out: File::NULL, err: File::NULL)
        system("git config user.name 'Test User'", out: File::NULL, err: File::NULL)
        
        # Create .gitignore to exclude memory/state files (shadow commit log)
        File.write(".gitignore", <<~GITIGNORE)
          # Workflow memory and state files (shadow commit log)
          *_memory.json
          sisyphus_memory.json
          workflow_memory.json
          research_memory.json
          **/workflows/**/*.json
          **/state/*.json
        GITIGNORE
        
        # Create initial commit so we have a valid Git history
        FileUtils.touch("README.md")
        system("git add .", out: File::NULL, err: File::NULL)
        system("git commit -m 'Initial commit'", out: File::NULL, err: File::NULL)
      end
      dir
    end
  end
end

# After all tests complete, check for explicit skip() calls
Minitest.after_run do
  test_dir = File.join(Rails.root, "test")
  skip_files = []
  
  Dir.glob("#{test_dir}/**/*_test.rb").each do |file|
    # Skip the speed_profile.rb file itself (it has legitimate skip for filtering)
    next if file.include?("support/speed_profile.rb")
    
    File.readlines(file).each_with_index do |line, index|
      # Match lines with skip calls (not commented out)
      if line.match?(/^\s*skip\b/) && !line.strip.start_with?("#")
        skip_files << { file: file.sub("#{Rails.root}/", ""), line: index + 1, content: line.strip }
      end
    end
  end
  
  if skip_files.any?
    # Print LOUD warning
    puts "\n\n"
    puts "=" * 80
    puts "⚠️  INVALID SKIPS DETECTED ⚠️".center(80)
    puts "=" * 80
    puts "\nThe following tests have explicit skip() calls which violate OOP Lesson 23:"
    puts "(Tests should fail loudly if misconfigured, not skip silently)\n\n"
    
    skip_files.each do |skip|
      puts "  #{skip[:file]}:#{skip[:line]}"
      puts "    #{skip[:content]}"
      puts ""
    end
    
    puts "All skip() calls must be removed. Tests should:"
    puts "  - Use proper configuration from .env.test"
    puts "  - Fail with clear errors if misconfigured"
    puts "  - Not hide problems with skip() calls"
    puts "\n"
    puts "=" * 80
    puts "\n"
  end
end
