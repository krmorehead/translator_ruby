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
    parallelize(workers: :number_of_processors) # Re-enabled with load distribution

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include FactoryBot methods
    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...
  end
end
