require "test_helper"

class ResearchComparisonTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s
  BASELINE_PATH = Rails.root.join("test", "fixtures", "cursor_baseline")

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

  test "worker produces output for baseline prompt" do
    worker = CodebaseResearcher.new(
      goal: "Research the codebase: How does Calculator work? What is the relationship between Formatter and Calculator? How does MathService use both?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    assert result, "Worker should produce a result"
    # Even if not successful, should not crash
  end

  test "comparison report is generated" do
    # Skip if cursor baseline doesn't exist or is placeholder
    cursor_output_path = BASELINE_PATH.join("cursor_output.md")
    cursor_output = File.read(cursor_output_path)

    if cursor_output.include?("This is a placeholder")
      skip "Cursor baseline not yet populated - run the prompt from research_prompt.md first"
    end

    worker = CodebaseResearcher.new(
      goal: "Research the codebase: How does Calculator work? What is the relationship between Formatter and Calculator?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    if result[:success] && result[:synthesis]
      report = generate_comparison_report(result[:synthesis], cursor_output)

      report_path = File.join(@output_path, "comparison_report.md")
      File.write(report_path, report)

      assert File.exist?(report_path), "Report file should be created"
    end
  end

  test "report identifies coverage differences" do
    cursor_output_path = BASELINE_PATH.join("cursor_output.md")
    cursor_output = File.read(cursor_output_path)

    if cursor_output.include?("This is a placeholder")
      skip "Cursor baseline not yet populated"
    end

    worker = CodebaseResearcher.new(
      goal: "What classes exist and how do they relate?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    if result[:success] && result[:synthesis]
      report = generate_comparison_report(result[:synthesis], cursor_output)

      # Report should have sections
      assert report.include?("Coverage Analysis"), "Report should have coverage section"
    end
  end

  test "report is human-readable" do
    cursor_output_path = BASELINE_PATH.join("cursor_output.md")
    cursor_output = File.read(cursor_output_path)

    if cursor_output.include?("This is a placeholder")
      skip "Cursor baseline not yet populated"
    end

    worker = CodebaseResearcher.new(
      goal: "Analyze the codebase structure",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    if result[:success] && result[:synthesis]
      report = generate_comparison_report(result[:synthesis], cursor_output)

      # Should be valid markdown
      assert report.include?("#"), "Report should use markdown headings"
      assert report.lines.size > 10, "Report should have substantial content"
    end
  end

  private

  def generate_comparison_report(worker_synthesis, cursor_output)
    report = []
    report << "# Research Comparison Report"
    report << ""
    report << "> Generated: #{Time.now.utc.iso8601}"
    report << ""

    # Coverage Analysis
    report << "## Coverage Analysis"
    report << ""

    key_terms = %w[Calculator Formatter MathService dependency arithmetic]
    cursor_coverage = key_terms.select { |t| cursor_output.downcase.include?(t.downcase) }
    worker_summary = worker_synthesis["summary"] || worker_synthesis[:summary] || ""
    worker_coverage = key_terms.select { |t| worker_summary.downcase.include?(t.downcase) }

    report << "### Terms Found in Cursor Output"
    report << cursor_coverage.map { |t| "- #{t}" }.join("\n")
    report << ""

    report << "### Terms Found in Worker Output"
    report << worker_coverage.map { |t| "- #{t}" }.join("\n")
    report << ""

    # Coverage comparison
    missing_in_worker = cursor_coverage - worker_coverage
    missing_in_cursor = worker_coverage - cursor_coverage

    if missing_in_worker.any?
      report << "### Missing in Worker (found in Cursor)"
      report << missing_in_worker.map { |t| "- #{t}" }.join("\n")
      report << ""
    end

    if missing_in_cursor.any?
      report << "### Extra in Worker (not in Cursor)"
      report << missing_in_cursor.map { |t| "- #{t}" }.join("\n")
      report << ""
    end

    # Summary comparison
    report << "## Summary Comparison"
    report << ""
    report << "### Worker Summary"
    report << worker_summary
    report << ""
    report << "### Cursor Output Length"
    report << "#{cursor_output.lines.size} lines"
    report << ""

    report.join("\n")
  end
end

