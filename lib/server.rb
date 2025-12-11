#!/usr/bin/env ruby

require_relative "../config/environment"

port = ENV["PORT"] || 3000
host = ENV["HOST"] || "localhost"

puts "Starting Rails server on #{host}:#{port}"
puts "Hello World endpoint: http://#{host}:#{port}/api/v1/hello/index"

exec "bundle", "exec", "rails", "server", "-p", port.to_s, "-b", host
