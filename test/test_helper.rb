ENV["RAILS_ENV"] ||= "test"

# Load test environment variables from .env.test
require "dotenv"
Dotenv.load(".env.test")

require_relative "../config/environment"
require "rails/test_help"
require "minitest/spec"

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
