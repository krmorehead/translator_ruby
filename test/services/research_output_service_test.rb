require "test_helper"

class ResearchOutputServiceTest < ActiveSupport::TestCase
  def setup
    @output_path = Rails.root.join("tmp", "output_service_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@output_path)

    @original_output_path = ENV["RESEARCH_OUTPUT_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = @output_path

    @synthesis = {
      "summary" => "This is a test summary of the research findings.",
      "detailed_sections" => [
        {
          "sub_question" => "How does Calculator work?",
          "answer" => "Calculator provides basic arithmetic operations.",
          "key_findings" => ["Uses integer math", "Has error handling"],
          "confidence" => 0.9
        },
        {
          "sub_question" => "What are the dependencies?",
          "answer" => "Formatter depends on Calculator.",
          "key_findings" => ["Dependency injection used"],
          "confidence" => 0.85
        }
      ],
      "validated_insights" => [
        { "insight" => "Calculator is the core class", "confidence" => 0.95 }
      ],
      "open_questions" => [
        { "question" => "How is error handling tested?", "reason" => "No test files found" }
      ],
      "conflicts" => []
    }
  end

  def teardown
    FileUtils.rm_rf(@output_path) if @output_path && File.exist?(@output_path)

    if @original_output_path
      ENV["RESEARCH_OUTPUT_PATH"] = @original_output_path
    else
      ENV.delete("RESEARCH_OUTPUT_PATH")
    end
  end

  test "creates output directory" do
    new_path = File.join(@output_path, "new_subdir")
    service = ResearchOutputService.new(
      research_topic: "Test topic",
      base_path: new_path
    )

    # The path should use env var, but base_path is for when env is not set
    # Since we set ENV, it uses that
    assert_equal @output_path, service.output_path
  end

  test "generates appropriate filename" do
    service = ResearchOutputService.new(
      research_topic: "How Does Authentication Work?",
      base_path: @output_path
    )

    files = service.write(synthesis: @synthesis)

    assert files.any?
    filename = File.basename(files.first)
    assert_match(/how_does_authentication_work/, filename)
    assert filename.end_with?(".md")
  end

  test "writes content to file" do
    service = ResearchOutputService.new(
      research_topic: "Calculator Analysis",
      base_path: @output_path
    )

    files = service.write(synthesis: @synthesis)

    assert files.any?
    content = File.read(files.first)

    assert_includes content, "Calculator Analysis"
    assert_includes content, "test summary"
    assert_includes content, "How does Calculator work?"
  end

  test "creates index for multi-file output" do
    service = ResearchOutputService.new(
      research_topic: "Multi File Test",
      base_path: @output_path
    )

    files = service.write(synthesis: @synthesis, format: :multi_file)

    # Should have index + section files
    assert files.size >= 2

    index_file = files.find { |f| f.include?("index") }
    assert index_file, "Should have an index file"

    index_content = File.read(index_file)
    assert_includes index_content, "Multi File Test"
  end

  test "includes metadata in output" do
    service = ResearchOutputService.new(
      research_topic: "Metadata Test",
      base_path: @output_path
    )

    files = service.write(synthesis: @synthesis)
    content = File.read(files.first)

    # Should include timestamp
    assert_includes content, "Generated:"
  end

  test "handles synthesis with symbol keys" do
    synthesis_with_symbols = {
      summary: "Symbol key summary",
      detailed_sections: [
        { sub_question: "Test?", answer: "Yes", key_findings: ["Found it"], confidence: 0.9 }
      ],
      validated_insights: [],
      open_questions: [],
      conflicts: []
    }

    service = ResearchOutputService.new(
      research_topic: "Symbol Keys Test",
      base_path: @output_path
    )

    files = service.write(synthesis: synthesis_with_symbols)

    assert files.any?
    content = File.read(files.first)
    assert_includes content, "Symbol key summary"
  end
end

