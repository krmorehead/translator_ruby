require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Requires supporting ruby files with custom matchers and macros, etc., in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by the vanilla RSpec command line.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Use color in output
  config.color = true

  # Run specs in random order to surface order dependencies. If you
  # discover an order dependency and want to debug it, you can fix the order by
  # management in the spec/ directory.
  config.order = :random
  config.seed = 0

  # Use expect syntax without mocks
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
