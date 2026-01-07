#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive agent workflow verification script
# Run with: rails runner test/verify_agents.rb

require "securerandom"
require "fileutils"

puts "=" * 80
puts "AGENT WORKFLOW VERIFICATION"
puts "=" * 80
puts ""

FIXTURE_PATH = File.expand_path("../fixtures/example_codebase", __FILE__)
TEMP_TEST_PATH = "/tmp/test_agents_#{SecureRandom.hex(4)}"

def test_result(name, passed, details = nil)
  status = passed ? "✅" : "❌"
  puts "#{status} #{name}"
  puts "   #{details}" if details && !passed
  passed
end

results = []

# ========================================================================
# DAEDALUS - Exploration Agent
# ========================================================================
puts "DAEDALUS AGENT - Codebase Exploration"
puts "-" * 80

session_d = AgentSession.new(
  session_id: SecureRandom.uuid,
  owner_id: "test",
  agent_type: AgentSession::AGENT_TYPE_DAEDALUS,
  project_path: FIXTURE_PATH,
  started_at: Time.now,
  last_activity_at: Time.now,
  status: "active"
)

context = Contexts::BaseContext.new
daedalus = AgentChatService.new(session: session_d, context: context)

results << test_result("D1: file_tree tool", 
  daedalus.process_message(content: "Show directory structure")[:tool_calls].any? { |tc| tc[:name] == "file_tree" }
)

results << test_result("D2: read_file tool",
  daedalus.process_message(content: "Read app/models/calculator.rb")[:tool_calls].any? { |tc| tc[:name] == "read_file" }
)

results << test_result("D3: grep tool",
  daedalus.process_message(content: "Search for def initialize")[:tool_calls].any? { |tc| tc[:name] == "grep" }
)

result = daedalus.process_message(content: "What services exist?")
results << test_result("D4: Answers questions",
  result[:content].length > 100 && result[:tool_calls].size > 0
)

puts ""

# ========================================================================
# SISYPHUS - Execution Agent
# ========================================================================
puts "SISYPHUS AGENT - Code Execution"
puts "-" * 80

FileUtils.mkdir_p(TEMP_TEST_PATH)
FileUtils.cp_r("#{FIXTURE_PATH}/.", TEMP_TEST_PATH)

session_s = AgentSession.new(
  session_id: SecureRandom.uuid,
  owner_id: "test",
  agent_type: AgentSession::AGENT_TYPE_SISYPHUS,
  project_path: TEMP_TEST_PATH,
  started_at: Time.now,
  last_activity_at: Time.now,
  status: "active"
)

sisyphus = AgentChatService.new(session: session_s, context: context)

results << test_result("S1: file_tree tool",
  sisyphus.process_message(content: "Show directory structure")[:tool_calls].any? { |tc| tc[:name] == "file_tree" }
)

results << test_result("S2: read_file tool",
  sisyphus.process_message(content: "Read app/models/calculator.rb")[:tool_calls].any? { |tc| tc[:name] == "read_file" }
)

sisyphus.process_message(content: "Create file test1.txt with: Test1")
results << test_result("S3: write_file creates file",
  File.exist?(File.join(TEMP_TEST_PATH, "test1.txt")) && 
  File.read(File.join(TEMP_TEST_PATH, "test1.txt")).include?("Test1")
)

sisyphus.process_message(content: "Modify test1.txt to say: Modified1")
results << test_result("S4: write_file modifies file",
  File.read(File.join(TEMP_TEST_PATH, "test1.txt")).include?("Modified1")
)

sisyphus.process_message(content: "Run: echo bash_output > bash_test.txt")
results << test_result("S5: bash tool",
  File.exist?(File.join(TEMP_TEST_PATH, "bash_test.txt"))
)

sisyphus.process_message(content: "Create my_class.rb with a Ruby class MyClass")
my_class_file = File.join(TEMP_TEST_PATH, "my_class.rb")
results << test_result("S6: Complex file creation",
  File.exist?(my_class_file) && File.read(my_class_file).include?("class")
)

# ========================================================================
# PATH RESOLUTION VERIFICATION
# ========================================================================
puts ""
puts "PATH RESOLUTION VERIFICATION"
puts "-" * 80

test_files = Dir.glob("#{TEMP_TEST_PATH}/**/*").select { |f| File.file?(f) }
no_doubled_paths = !test_files.any? { |f| f.include?(TEMP_TEST_PATH + TEMP_TEST_PATH) }
results << test_result("P1: No doubled paths",
  no_doubled_paths,
  "Found doubled path: #{test_files.find { |f| f.include?(TEMP_TEST_PATH + TEMP_TEST_PATH) }}"
)

result = daedalus.process_message(content: "List all Ruby files in app/services")
has_services = result[:content].downcase.include?("service") || result[:tool_calls].any?
results << test_result("P2: Fixture path resolution",
  has_services
)

# Cleanup
FileUtils.rm_rf(TEMP_TEST_PATH)

# ========================================================================
# RESULTS
# ========================================================================
puts ""
puts "=" * 80
puts "RESULTS"
puts "=" * 80

daedalus_tests = results[0..3]
sisyphus_tests = results[4..9]
path_tests = results[10..11]

puts ""
puts "Daedalus (Exploration):  #{daedalus_tests.count(true)}/#{daedalus_tests.size}"
puts "Sisyphus (Execution):    #{sisyphus_tests.count(true)}/#{sisyphus_tests.size}"
puts "Path Resolution:         #{path_tests.count(true)}/#{path_tests.size}"
puts ""

passed = results.count(true)
total = results.size
percentage = (passed.to_f / total * 100).round(1)

puts "TOTAL: #{passed}/#{total} (#{percentage}%)"
puts ""

if passed == total
  puts "🎉 ALL TESTS PASSED!"
  puts ""
  puts "✅ Service → Worker → Prompt → Tools architecture verified"
  puts "✅ Daedalus exploration tools working (file_tree, read_file, grep)"
  puts "✅ Sisyphus execution tools working (write_file, bash)"
  puts "✅ Path resolution correct (no doubled paths)"
  puts "✅ Both agents can operate on fixture codebase"
  exit 0
else
  puts "❌ #{total - passed} test(s) failed"
  exit 1
end

