#!/usr/bin/env ruby

require_relative '../config/environment'
require 'dotenv/load' if File.exist?('.env')

port = ENV['PORT'] || 3000

puts "Starting Rails server on port #{port}"
puts "Hello World endpoint: http://localhost:#{port}/api/v1/hello/index"

exec "bundle", "exec", "rails", "server", "-p", port.to_s 