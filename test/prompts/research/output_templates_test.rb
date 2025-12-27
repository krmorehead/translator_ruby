# frozen_string_literal: true

require "test_helper"

class OutputTemplatesTest < ActiveSupport::TestCase
  describe Research::OutputTemplates::BaseOutputTemplate do
    test "raises NotImplementedError for template_name" do
      template = Research::OutputTemplates::BaseOutputTemplate.new
      assert_raises(NotImplementedError) { template.template_name }
    end

    test "raises NotImplementedError for render" do
      template = Research::OutputTemplates::BaseOutputTemplate.new
      assert_raises(NotImplementedError) { template.render({}) }
    end
  end

  describe Research::OutputTemplates::FileDocTemplate do
    setup do
      @template = Research::OutputTemplates::FileDocTemplate.new
    end

    test "template_name returns file_doc" do
      assert_equal "file_doc", @template.template_name
    end

    test "renders basic file documentation" do
      data = {
        file_path: "lib/calculator.rb",
        summary: "A calculator class for basic math operations.",
        external_references: ["lib/formatter.rb"],
        methods: [
          {
            name: "add",
            purpose: "Adds two numbers",
            parameters: [{ name: "a", type: "Integer" }, { name: "b", type: "Integer" }],
            returns: "Integer sum",
            calls: []
          },
          {
            name: "subtract",
            purpose: "Subtracts two numbers",
            parameters: [{ name: "a" }, { name: "b" }],
            returns: "Integer difference",
            calls: ["validate_numbers"]
          }
        ]
      }

      result = @template.render(data)

      assert_includes result, "# lib/calculator.rb"
      assert_includes result, "## Summary"
      assert_includes result, "A calculator class for basic math operations."
      assert_includes result, "## Source"
      assert_includes result, "[View Code](lib/calculator.rb)"
      assert_includes result, "## External References"
      assert_includes result, "```mermaid"
      assert_includes result, "graph LR"
      assert_includes result, "formatter.rb"
      assert_includes result, "## Method Architecture"
      assert_includes result, "flowchart TD"
      assert_includes result, "## Methods"
      assert_includes result, "### add"
      assert_includes result, "Adds two numbers"
      assert_includes result, "### subtract"
    end

    test "handles file with no external references" do
      data = {
        file_path: "standalone.rb",
        summary: "A standalone file",
        external_references: [],
        methods: []
      }

      result = @template.render(data)

      assert_includes result, "*No external file references detected.*"
    end

    test "handles file with no methods" do
      data = {
        file_path: "config.rb",
        summary: "Configuration file",
        external_references: [],
        methods: []
      }

      result = @template.render(data)

      assert_includes result, "*No methods documented.*"
    end
  end

  describe Research::OutputTemplates::BaseReferencesTemplate do
    setup do
      @template = Research::OutputTemplates::BaseReferencesTemplate.new
    end

    test "template_name returns base_references" do
      assert_equal "base_references", @template.template_name
    end

    test "renders directory tree" do
      data = {
        directory_path: "lib",
        files: [
          { path: "lib/calculator.rb", description: "Math operations" },
          { path: "lib/formatter.rb", description: "Number formatting" }
        ],
        subdirectories: ["helpers"]
      }

      result = @template.render(data)

      assert_includes result, "# lib Reference Index"
      assert_includes result, "```"
      assert_includes result, "├── helpers/"
      assert_includes result, "calculator.md"
      assert_includes result, "# Math operations"
      assert_includes result, "formatter.md"
      assert_includes result, "## Files"
      assert_includes result, "## Subdirectories"
      assert_includes result, "[helpers/](helpers/base_references.md)"
    end

    test "renders root directory" do
      data = {
        directory_path: ".",
        files: [{ path: "main.rb", description: "Entry point" }],
        subdirectories: ["lib", "app"]
      }

      result = @template.render(data)

      assert_includes result, "# Research References"
    end
  end

  describe Research::OutputTemplates::SynthesisSummaryTemplate do
    setup do
      @template = Research::OutputTemplates::SynthesisSummaryTemplate.new
    end

    test "template_name returns synthesis_summary" do
      assert_equal "synthesis_summary", @template.template_name
    end

    test "renders synthesis summary" do
      data = {
        research_goal: "How does the calculator work?",
        summary: "The calculator provides basic math operations through a simple interface.",
        documented_files: [
          { path: "lib/calculator.rb", sub_questions: ["Q1", "Q2"] },
          { path: "lib/formatter.rb", sub_questions: ["Q2"] }
        ],
        sub_questions: [
          { question: "What methods does it have?", answer: "add, subtract, multiply, divide" }
        ],
        open_questions: [
          { question: "How is division by zero handled?", reason: "Not found in code" }
        ]
      }

      result = @template.render(data)

      assert_includes result, "# Research Summary"
      assert_includes result, "How does the calculator work?"
      assert_includes result, "## Answer"
      assert_includes result, "basic math operations"
      assert_includes result, "## Questions Investigated"
      assert_includes result, "What methods does it have?"
      assert_includes result, "## Documented Files"
      assert_includes result, "calculator.rb"
      assert_includes result, "## Open Questions"
      assert_includes result, "division by zero"
    end
  end

  describe Research::OutputTemplates::ReportTemplate do
    setup do
      @template = Research::OutputTemplates::ReportTemplate.new
    end

    test "template_name returns report" do
      assert_equal "report", @template.template_name
    end

    test "renders research report" do
      data = {
        research_topic: "How authentication works",
        summary: "Authentication uses JWT tokens.",
        detailed_sections: [
          { sub_question: "How are tokens generated?", answer: "Using JWT library", key_findings: ["Uses HS256"] }
        ],
        validated_insights: ["Tokens expire after 24 hours"],
        open_questions: ["What about refresh tokens?"]
      }

      result = @template.render(data)

      assert_includes result, "# Research: How authentication works"
      assert_includes result, "## Summary"
      assert_includes result, "JWT tokens"
      assert_includes result, "## Table of Contents"
      assert_includes result, "## How are tokens generated?"
      assert_includes result, "### Key Findings"
      assert_includes result, "HS256"
      assert_includes result, "## Validated Insights"
      assert_includes result, "Tokens expire"
      assert_includes result, "## Open Questions"
    end
  end
end

