#!/usr/bin/env ruby
require "dotenv/load" if File.exist?(".env")

# Set test environment
ENV["RAILS_ENV"] = "test"

# Run the tests
exec "bundle", "exec", "rails", "test", *ARGV
