require "test_helper"

class ResearchOutputServiceTest < ActiveSupport::TestCase
  def setup
    @output_path = Rails.root.join("tmp", "output_service_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@output_path)

    @original_output_path = ENV["RESEARCH_OUTPUT_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = @output_path

    @synthesis = {
      summary: "This is a test summary of the research findings.",
      detailed_sections: [
        {
          sub_question: "How does Calculator work?",
          answer: "Calculator provides basic arithmetic operations.",
          key_findings: ["Uses integer math", "Has error handling"],
          confidence: 0.9
        },
        {
          sub_question: "What are the dependencies?",
          answer: "Formatter depends on Calculator.",
          key_findings: ["Dependency injection used"],
          confidence: 0.85
        }
      ],
      validated_insights: ["Calculator is the core class"],
      open_questions: ["How is error handling tested?"],
      conflicts: []
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

    files = service.write(synthesis: @synthesis, output_modes: [:report], report_format: :multi_file)

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

  # Documentation mode tests
  test "documentation mode creates mirrored directory structure" do
    # Create a temp source directory
    source_dir = File.join(@output_path, "source")
    FileUtils.mkdir_p(source_dir)

    # Reset env to use source_dir as base
    ENV.delete("RESEARCH_OUTPUT_PATH")

    service = ResearchOutputService.new(
      research_topic: "Doc Mode Test",
      base_path: source_dir
    )

    file_analyses = [
      {
        file_path: "lib/calculator.rb",
        summary: "Calculator class",
        external_references: [],
        methods: [{ name: "add", purpose: "Adds numbers" }]
      },
      {
        file_path: "lib/formatter.rb",
        summary: "Formatter class",
        external_references: ["lib/calculator.rb"],
        methods: []
      }
    ]

    files = service.write(synthesis: @synthesis, output_modes: [:documentation], file_analyses: file_analyses)

    assert files.any?

    # Should create per-file docs
    assert files.any? { |f| f.include?("calculator.md") }
    assert files.any? { |f| f.include?("formatter.md") }

    # Should create base_references.md
    assert files.any? { |f| f.include?("base_references.md") }

    # Should create synthesis_summary.md
    assert files.any? { |f| f.include?("synthesis_summary.md") }
  end

  test "documentation mode generates per-file markdown" do
    source_dir = File.join(@output_path, "source2")
    FileUtils.mkdir_p(source_dir)

    ENV.delete("RESEARCH_OUTPUT_PATH")

    service = ResearchOutputService.new(
      research_topic: "Per File Test",
      base_path: source_dir
    )

    file_analyses = [
      {
        file_path: "lib/test.rb",
        summary: "Test file summary",
        external_references: ["lib/helper.rb"],
        methods: [
          { name: "test_method", purpose: "Does testing", parameters: [], returns: "Boolean", calls: [] }
        ]
      }
    ]

    files = service.write(synthesis: @synthesis, output_modes: [:documentation], file_analyses: file_analyses)

    test_md = files.find { |f| f.include?("test.md") }
    assert test_md, "Should create test.md"

    content = File.read(test_md)
    assert_includes content, "Test file summary"
    assert_includes content, "test_method"
    assert_includes content, "helper.rb"
  end

  test "documentation mode generates synthesis_summary" do
    source_dir = File.join(@output_path, "source3")
    FileUtils.mkdir_p(source_dir)

    ENV.delete("RESEARCH_OUTPUT_PATH")

    service = ResearchOutputService.new(
      research_topic: "Synthesis Test",
      base_path: source_dir
    )

    files = service.write(synthesis: @synthesis, output_modes: [:documentation], file_analyses: [])

    summary_file = files.find { |f| f.include?("synthesis_summary.md") }
    assert summary_file, "Should create synthesis_summary.md"

    content = File.read(summary_file)
    assert_includes content, "Synthesis Test"
    assert_includes content, "test summary"
  end

  test "both output_modes generates report and documentation" do
    source_dir = File.join(@output_path, "source_both")
    FileUtils.mkdir_p(source_dir)

    ENV.delete("RESEARCH_OUTPUT_PATH")

    service = ResearchOutputService.new(
      research_topic: "Both Modes Test",
      base_path: source_dir
    )

    file_analyses = [
      {
        file_path: "lib/example.rb",
        summary: "Example class",
        external_references: [],
        methods: [{ name: "run", purpose: "Runs example" }]
      }
    ]

    files = service.write(synthesis: @synthesis, output_modes: [:report, :documentation], file_analyses: file_analyses)

    # Should have both report and documentation files
    assert files.any? { |f| f.include?("both_modes_test") && !f.include?("synthesis_summary") }, "Should have report file"
    assert files.any? { |f| f.include?("example.md") }, "Should have per-file doc"
    assert files.any? { |f| f.include?("synthesis_summary.md") }, "Should have synthesis summary"
    assert files.any? { |f| f.include?("base_references.md") }, "Should have base_references"
  end
end

