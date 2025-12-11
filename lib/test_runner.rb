#!/usr/bin/env ruby

# Set test environment
ENV["RAILS_ENV"] = "test"

# Run the tests
exec "bundle", "exec", "rails", "test", *ARGV
