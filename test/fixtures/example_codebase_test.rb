require "test_helper"

class ExampleCodebaseTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase")

  test "fixture files exist" do
    assert File.exist?(FIXTURE_PATH.join("lib", "calculator.rb"))
    assert File.exist?(FIXTURE_PATH.join("lib", "formatter.rb"))
    assert File.exist?(FIXTURE_PATH.join("app", "services", "math_service.rb"))
    assert File.exist?(FIXTURE_PATH.join("README.md"))
    assert File.exist?(FIXTURE_PATH.join("Gemfile"))
  end

  test "fixture is valid Ruby that can be parsed" do
    ruby_files = Dir.glob(FIXTURE_PATH.join("**", "*.rb"))
    assert ruby_files.size >= 3, "Should have at least 3 Ruby files"

    ruby_files.each do |file|
      content = File.read(file)
      # Parsing should not raise an error
      begin
        RubyVM::InstructionSequence.compile(content)
      rescue SyntaxError => e
        flunk "#{file} is not valid Ruby: #{e.message}"
      end
    end
  end

  test "dependencies are traceable in source" do
    # MathService should reference Calculator and Formatter
    math_service = File.read(FIXTURE_PATH.join("app", "services", "math_service.rb"))
    assert_includes math_service, "Calculator", "MathService should reference Calculator"
    assert_includes math_service, "Formatter", "MathService should reference Formatter"

    # Formatter should reference Calculator
    formatter = File.read(FIXTURE_PATH.join("lib", "formatter.rb"))
    assert_includes formatter, "Calculator", "Formatter should reference Calculator"

    # Calculator is standalone
    calculator = File.read(FIXTURE_PATH.join("lib", "calculator.rb"))
    refute_includes calculator, "Formatter", "Calculator should not reference Formatter"
    refute_includes calculator, "MathService", "Calculator should not reference MathService"
  end

  test "README documents the architecture" do
    readme = File.read(FIXTURE_PATH.join("README.md"))

    assert_includes readme, "Calculator"
    assert_includes readme, "Formatter"
    assert_includes readme, "MathService"
    assert_includes readme, "Dependencies"
  end
end

