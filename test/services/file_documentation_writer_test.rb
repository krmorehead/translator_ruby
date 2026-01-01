# frozen_string_literal: true

require "test_helper"

class FileDocumentationWriterTest < ActiveSupport::TestCase
  setup do
    @output_dir = Dir.mktmpdir("doc_writer_test")
    @source_dir = Dir.mktmpdir("source_test")
    @writer = FileDocumentationWriter.new(
      output_base_path: @output_dir,
      source_base_path: @source_dir
    )
  end

  teardown do
    FileUtils.rm_rf(@output_dir) if @output_dir && File.exist?(@output_dir)
    FileUtils.rm_rf(@source_dir) if @source_dir && File.exist?(@source_dir)
  end
  speed_profile :fast
  test "writes file documentation" do
    analysis = {
      file_path: "#{@source_dir}/lib/calculator.rb",
      summary: "Calculator for math operations",
      external_references: ["lib/formatter.rb"],
      methods: [
        { name: "add", purpose: "Adds numbers", parameters: [], returns: "Integer", calls: [] }
      ],
      relevant_sub_questions: ["How does addition work?"]
    }

    path = @writer.write_file_doc(file_analysis: analysis)

    assert File.exist?(path)
    content = File.read(path)
    assert_includes content, "# lib/calculator.rb"
    assert_includes content, "Calculator for math operations"
  end

  speed_profile :fast
  test "creates directory structure" do
    analysis = {
      file_path: "#{@source_dir}/app/services/math_service.rb",
      summary: "Math service",
      external_references: [],
      methods: []
    }

    path = @writer.write_file_doc(file_analysis: analysis)

    assert File.exist?(path)
    assert_includes path, "app/services/math_service.md"
  end

  speed_profile :fast
  test "writes base_references for directory" do
    files = [
      { path: "lib/calculator.rb", description: "Math operations" },
      { path: "lib/formatter.rb", description: "Formatting" }
    ]

    path = @writer.write_base_references(directory: "lib", files: files)

    assert File.exist?(path)
    content = File.read(path)
    assert_includes content, "calculator.md"
    assert_includes content, "formatter.md"
    assert_includes content, "# Math operations"
  end

  speed_profile :fast
  test "writes synthesis summary" do
    synthesis = {
      research_goal: "How does the calculator work?",
      summary: "It does math.",
      sub_questions: [],
      open_questions: []
    }

    path = @writer.write_synthesis_summary(synthesis: synthesis)

    assert File.exist?(path)
    content = File.read(path)
    assert_includes content, "Research Summary"
    assert_includes content, "How does the calculator work?"
  end

  speed_profile :fast
  test "generates all base_references" do
    # Document some files first
    %w[lib/a.rb lib/b.rb app/c.rb].each do |rel_path|
      @writer.write_file_doc(file_analysis: {
        file_path: "#{@source_dir}/#{rel_path}",
        summary: "File #{rel_path}",
        external_references: [],
        methods: []
      })
    end

    paths = @writer.generate_all_base_references

    assert paths.any?
    # Should have base_references for lib/, app/, and root
    assert paths.any? { |p| p.include?("lib/base_references.md") }
    assert paths.any? { |p| p.include?("app/base_references.md") }
  end

  speed_profile :fast
  test "tracks documented files" do
    analysis = {
      file_path: "#{@source_dir}/lib/test.rb",
      summary: "Test file",
      external_references: [],
      methods: [],
      relevant_sub_questions: ["Q1"]
    }

    @writer.write_file_doc(file_analysis: analysis)

    assert_includes @writer.documented_file_paths, "lib/test.rb"
  end
end

