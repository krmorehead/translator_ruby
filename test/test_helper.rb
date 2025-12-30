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

    # Clean up test agent data after each test
    teardown do
      cleanup_test_agent_data
    end

    
    def cleanup_test_agent_data
      test_data_path = ENV.fetch("AGENT_DATA_PATH", "tmp/test_agent_data")
      FileUtils.rm_rf(test_data_path) if File.exist?(test_data_path)
    end
  end
end

# Also clean up at the end of the entire test run
Minitest.after_run do
  test_data_path = ENV.fetch("AGENT_DATA_PATH", "tmp/test_agent_data")
  FileUtils.rm_rf(test_data_path) if File.exist?(test_data_path)
  
  # Also clean up any tmp/tool_test directories from older test patterns
  FileUtils.rm_rf(Rails.root.join("tmp", "tool_test")) if File.exist?(Rails.root.join("tmp", "tool_test"))
  FileUtils.rm_rf(Rails.root.join("tmp", "dnd_chat_sandbox")) if File.exist?(Rails.root.join("tmp", "dnd_chat_sandbox"))
end
