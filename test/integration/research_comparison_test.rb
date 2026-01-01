require "test_helper"

class ResearchComparisonTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s
  BASELINE_PATH = Rails.root.join("test", "fixtures", "cursor_baseline")
  EXPECTED_OUTPUT_PATH = BASELINE_PATH.join("expected_output")

  # Expected files from Cursor baseline
  EXPECTED_FILES = %w[
    base_references.md
    synthesis_summary.md
    lib/calculator.md
    lib/formatter.md
    app/services/math_service.md
  ].freeze

  # Key terms that should appear in research output
  KEY_TERMS = %w[Calculator Formatter MathService dependency arithmetic].freeze

  # Irrelevant files that should NOT be in relevant_files for math-focused research
  IRRELEVANT_FILES = %w[logger config_manager user_service notification_service].freeze

  # ============================================================================
  # Shared Worker Result - runs once, used by multiple tests
  # ============================================================================

  class << self
    attr_accessor :shared_result, :shared_result_computed
  end

  def shared_research_result
    return self.class.shared_result if self.class.shared_result_computed

    # Ensure output directory exists for this test run
    output_path = Rails.root.join("tmp", "shared_comparison_test_#{Process.pid}").to_s
    FileUtils.mkdir_p(output_path)

    original_output_path = ENV["RESEARCH_OUTPUT_PATH"]
    original_state_path = ENV["AGENT_STATE_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = output_path
    ENV["AGENT_STATE_PATH"] = output_path

    begin
      worker = CodebaseResearcher.new(
        goal: "How does Calculator work? What is the relationship between Formatter and Calculator? How does MathService use both?",
        path: FIXTURE_PATH,
        output_modes: [:report, :documentation]
      )

      self.class.shared_result = worker.execute
      self.class.shared_result_computed = true
    ensure
      ENV["RESEARCH_OUTPUT_PATH"] = original_output_path || ENV.delete("RESEARCH_OUTPUT_PATH")
      ENV["AGENT_STATE_PATH"] = original_state_path || ENV.delete("AGENT_STATE_PATH")
    end

    self.class.shared_result
  end

  def setup
    @output_path = Rails.root.join("tmp", "comparison_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@output_path)

    @original_output_path = ENV["RESEARCH_OUTPUT_PATH"]
    @original_state_path = ENV["AGENT_STATE_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = @output_path
    ENV["AGENT_STATE_PATH"] = @output_path
  end

  def teardown
    FileUtils.rm_rf(@output_path) if @output_path && File.exist?(@output_path)

    if @original_output_path
      ENV["RESEARCH_OUTPUT_PATH"] = @original_output_path
    else
      ENV.delete("RESEARCH_OUTPUT_PATH")
    end

    if @original_state_path
      ENV["AGENT_STATE_PATH"] = @original_state_path
    else
      ENV.delete("AGENT_STATE_PATH")
    end
  end

  # ============================================================================
  # Baseline Verification Tests (no LLM calls needed)
  # ============================================================================
  speed_profile :slow
  test "cursor baseline expected_output structure exists" do
    EXPECTED_FILES.each do |file|
      path = EXPECTED_OUTPUT_PATH.join(file)
      assert File.exist?(path), "Expected baseline file missing: #{file}"
    end
  end

  speed_profile :slow
  test "cursor baseline files have content" do
    EXPECTED_FILES.each do |file|
      path = EXPECTED_OUTPUT_PATH.join(file)
      content = File.read(path)
      assert content.length > 100, "Expected baseline file #{file} to have substantial content"
    end
  end

  # ============================================================================
  # Shared Result Tests - all use the same worker run
  # ============================================================================

  speed_profile :slow
  test "shared: worker produces successful result" do
    result = shared_research_result
    assert result, "Worker should produce a result"
    assert result[:success], "Worker should succeed"
  end

  speed_profile :slow
  test "shared: worker produces synthesis" do
    result = shared_research_result
    assert result[:synthesis], "Worker should produce synthesis"
  end

  speed_profile :slow
  test "shared: worker generates file analyses" do
    result = shared_research_result
    assert result[:file_analyses], "Worker should produce file analyses"
    assert result[:file_analyses].any?, "Should have at least one file analysis"
  end

  speed_profile :slow
  test "shared: worker generates findings" do
    result = shared_research_result
    assert result[:findings], "Worker should have findings"
  end

  speed_profile :slow
  test "shared: both output modes reported" do
    result = shared_research_result
    assert_includes result[:output_modes], :report
    assert_includes result[:output_modes], :documentation
  end

  speed_profile :slow
  test "shared: relevant_files array present" do
    result = shared_research_result
    assert result[:relevant_files], "Should have relevant_files array"
  end

  speed_profile :slow
  test "shared: relevant_files_tree present" do
    result = shared_research_result
    assert result[:relevant_files_tree], "Should have relevant_files_tree"
  end

  # ============================================================================
  # Relevance Filtering Tests (using shared result)
  # ============================================================================

  speed_profile :slow
  test "shared: relevant_files excludes unrelated files" do
    result = shared_research_result

    relevant_paths = (result[:relevant_files] || []).map { |f| f[:file_path] || f["file_path"] || "" }
    relevant_basenames = relevant_paths.map { |p| File.basename(p, ".*").downcase }

    IRRELEVANT_FILES.each do |irrelevant|
      refute relevant_basenames.include?(irrelevant),
             "Relevant files should NOT include #{irrelevant} (found: #{relevant_basenames.join(', ')})"
    end
  end

  speed_profile :slow
  test "shared: relevant_files includes math-related files" do
    result = shared_research_result

    relevant_paths = (result[:relevant_files] || []).map { |f| f[:file_path] || f["file_path"] || "" }
    relevant_basenames = relevant_paths.map { |p| File.basename(p, ".*").downcase }

    has_relevant = relevant_basenames.include?("calculator") ||
                   relevant_basenames.include?("formatter") ||
                   relevant_basenames.include?("math_service")

    assert has_relevant, "Should include calculator, formatter, or math_service (found: #{relevant_basenames.join(', ')})"
  end

  speed_profile :slow
  test "shared: relevant files have relevance scores" do
    result = shared_research_result

    if result[:relevant_files]&.any?
      result[:relevant_files].each do |file|
        assert file[:relevance_score] || file["relevance_score"],
               "Each relevant file should have a relevance_score"
        score = file[:relevance_score] || file["relevance_score"]
        assert score >= 0.5, "Relevant files should have score >= 0.5 (got: #{score})"
      end
    end
  end

  speed_profile :slow
  test "shared: relevant files include sub_question context" do
    result = shared_research_result

    if result[:relevant_files]&.any?
      result[:relevant_files].each do |file|
        assert file[:sub_question] || file["sub_question"],
               "Each relevant file should be tagged with the sub_question it answers"
      end
    end
  end

  # ============================================================================
  # Coverage Comparison Tests (using shared result)
  # ============================================================================

  speed_profile :slow
  test "shared: worker covers key terms" do
    result = shared_research_result
    cursor_output = File.read(BASELINE_PATH.join("cursor_output.md"))

    cursor_coverage = KEY_TERMS.select { |t| cursor_output.downcase.include?(t.downcase) }

    # Collect all worker text
    worker_summary = result[:synthesis]["summary"] || result[:synthesis][:summary] || ""
    findings_text = (result[:findings] || []).map { |f| f[:text] || f["text"] || "" }.join(" ")
    all_worker_text = [worker_summary, findings_text].join(" ").downcase

    worker_coverage = KEY_TERMS.select { |t| all_worker_text.include?(t.downcase) }

    # Worker should cover at least 50% of what Cursor covers
    if cursor_coverage.any?
      overlap = (worker_coverage & cursor_coverage).size
      coverage_ratio = overlap.to_f / cursor_coverage.size
      assert coverage_ratio >= 0.5,
             "Worker should cover at least 50% of key terms. Cursor: #{cursor_coverage}, Worker: #{worker_coverage}, Ratio: #{coverage_ratio}"
    end
  end

  speed_profile :slow
  test "shared: worker identifies same classes as cursor baseline" do
    result = shared_research_result
    cursor_base_refs = File.read(EXPECTED_OUTPUT_PATH.join("base_references.md"))

    # Combine all searchable text from worker
    analyzed_paths = (result[:file_analyses] || []).map { |a| (a[:file_path] || a["file_path"] || "").downcase }
    findings_text = (result[:findings] || []).map { |f| (f[:text] || f["text"] || "").downcase }.join(" ")
    synthesis_summary = (result[:synthesis][:summary] || result[:synthesis]["summary"] || "").downcase
    all_worker_text = [analyzed_paths.join(" "), findings_text, synthesis_summary].join(" ")

    if cursor_base_refs.include?("calculator")
      assert all_worker_text.include?("calculator"), "Worker should identify Calculator"
    end

    if cursor_base_refs.include?("formatter")
      assert all_worker_text.include?("formatter"), "Worker should identify Formatter"
    end
  end

  # ============================================================================
  # Documentation Structure Tests (using shared result)
  # ============================================================================

  speed_profile :slow
  test "shared: file analyses have required structure" do
    result = shared_research_result

    if result[:file_analyses]&.any?
      result[:file_analyses].each do |analysis|
        assert analysis[:summary] || analysis["summary"], "File analysis should have summary"
      end
    end
  end

  # ============================================================================
  # Comparison Report Generation (separate worker run for full comparison)
  # ============================================================================

  speed_profile :slow
  test "comparison report can be generated" do
    result = shared_research_result
    cursor_output = File.read(BASELINE_PATH.join("cursor_output.md"))

    if result[:success] && result[:synthesis]
      report = generate_comparison_report(result, cursor_output)

      report_path = File.join(@output_path, "comparison_report.md")
      File.write(report_path, report)

      assert File.exist?(report_path), "Report file should be created"
      assert report.include?("Coverage Analysis"), "Report should have coverage section"
    end
  end

  
  def generate_comparison_report(worker_result, cursor_output)
    report = []
    report << "# Research Comparison Report"
    report << ""
    report << "> Generated: #{Time.now.utc.iso8601}"
    report << ""

    # Coverage Analysis
    report << "## Coverage Analysis"
    report << ""

    cursor_coverage = KEY_TERMS.select { |t| cursor_output.downcase.include?(t.downcase) }
    worker_summary = worker_result[:synthesis]["summary"] || worker_result[:synthesis][:summary] || ""
    worker_coverage = KEY_TERMS.select { |t| worker_summary.downcase.include?(t.downcase) }

    report << "### Terms Found in Cursor Output"
    report << cursor_coverage.map { |t| "- #{t}" }.join("\n")
    report << ""

    report << "### Terms Found in Worker Output"
    report << worker_coverage.map { |t| "- #{t}" }.join("\n")
    report << ""

    # Relevance Filtering
    report << "## Relevance Filtering"
    report << ""
    relevant = worker_result[:relevant_files] || []
    report << "Relevant files: #{relevant.size}"
    relevant.each do |f|
      path = f[:file_path] || f["file_path"]
      score = f[:relevance_score] || f["relevance_score"]
      report << "- #{File.basename(path)} (score: #{score})"
    end
    report << ""

    # File Tree
    if worker_result[:relevant_files_tree].present?
      report << "## Relevant Files Tree"
      report << "```"
      report << worker_result[:relevant_files_tree]
      report << "```"
      report << ""
    end

    # Statistics
    report << "## Statistics"
    report << ""
    report << "| Metric | Worker |"
    report << "|--------|--------|"
    report << "| Files Analyzed | #{(worker_result[:file_analyses] || []).size} |"
    report << "| Findings Count | #{(worker_result[:findings] || []).size} |"
    report << "| Relevant Files | #{relevant.size} |"
    report << ""

    report.join("\n")
  end
end
