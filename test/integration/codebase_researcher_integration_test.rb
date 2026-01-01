# frozen_string_literal: true

require "test_helper"

class CodebaseResearcherIntegrationTest < ActiveSupport::TestCase
  include ResearchTestFactory

  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  # Shared execution result - runs once for primary tests
  class << self
    attr_accessor :shared_result, :shared_worker, :shared_computed
  end

  def shared_execution
    return [self.class.shared_worker, self.class.shared_result] if self.class.shared_computed

    worker = CodebaseResearcher.new(
      goal: "How does Calculator work? What are the dependencies between services?",
      path: FIXTURE_PATH,
      max_depth: 2,
      output_modes: [:report, :documentation]
    )
    result = worker.execute

    self.class.shared_worker = worker
    self.class.shared_result = result
    self.class.shared_computed = true

    [worker, result]
  end

  def setup
    @output_path = Rails.root.join("tmp", "research_output_#{Process.pid}_#{Thread.current.object_id}").to_s
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
  # Shared Execution Tests - All use same LLM call
  # ============================================================================
  speed_profile :slow
  test "shared: research succeeds on fixture codebase" do
    _worker, result = shared_execution

    assert result[:success], "Research should succeed: #{result[:error]}"
    assert_not_nil result[:owner_id]
  end

  speed_profile :slow
  test "shared: returns findings array" do
    _worker, result = shared_execution

    assert result[:findings].is_a?(Array)
  end

  speed_profile :slow
  test "shared: synthesis has summary" do
    _worker, result = shared_execution

    synthesis = result[:synthesis]
    assert synthesis, "Should have synthesis"

    summary = synthesis["summary"] || synthesis[:summary] || ""
    assert summary.present?, "Should have a summary"
  end

  speed_profile :slow
  test "shared: memory contains research goal" do
    _worker, result = shared_execution

    memory = result[:memory]
    assert memory, "Should have memory data"
    assert memory[:research_goal] || memory["research_goal"], "Should have research goal"
  end

  speed_profile :slow
  test "shared: discovered files are unique" do
    _worker, result = shared_execution

    memory = result[:memory]
    discovered = memory[:discovered_files] || memory["discovered_files"] || []

    file_paths = discovered.map { |d| d[:path] || d["path"] }.compact
    assert_equal file_paths.size, file_paths.uniq.size,
                 "Each file should only be recorded once in discovered_files"
  end

  speed_profile :slow
  test "shared: can write output files from synthesis" do
    _worker, result = shared_execution

    if result[:synthesis]
      output_service = ResearchOutputService.new(
        research_topic: "Integration test",
        base_path: FIXTURE_PATH
      )
      files = output_service.write(
        synthesis: result[:synthesis],
        file_analyses: result[:file_analyses] || [],
        output_modes: [:report]
      )

      assert files.any?, "Should create output files"
      files.each do |file_path|
        assert File.exist?(file_path), "Output file should exist: #{file_path}"
      end
    end
  end

  # ============================================================================
  # Separate Execution Tests - These need their own runs
  # ============================================================================

  speed_profile :slow
  test "multiple parallel research sessions have unique owner_ids" do
    workers = 2.times.map do |i|
      CodebaseResearcher.new(
        goal: "Research topic #{i}",
        path: FIXTURE_PATH,
        max_depth: 1
      )
    end

    results = workers.map(&:execute)

    owner_ids = results.map { |r| r[:owner_id] }
    assert_equal owner_ids.uniq.size, owner_ids.size, "Each worker should have unique owner_id"

    results.each_with_index do |r, i|
      assert r[:success], "Worker #{i} should succeed"
    end
  end

  speed_profile :slow
  test "handles empty codebase gracefully" do
    empty_dir = Rails.root.join("tmp", "empty_codebase_#{Process.pid}").to_s
    FileUtils.mkdir_p(empty_dir)

    begin
      worker = CodebaseResearcher.new(
        goal: "What is in this codebase?",
        path: empty_dir,
        max_depth: 1
      )

      result = worker.execute

      assert result, "Should return a result"
    ensure
      FileUtils.rm_rf(empty_dir)
    end
  end

  speed_profile :slow
  test "terminates gracefully when no relevant files found" do
    worker = CodebaseResearcher.new(
      goal: "How does the quantum flux capacitor integrate with the warp drive?",
      path: FIXTURE_PATH,
      max_depth: 1
    )

    result = worker.execute

    assert result, "Should return a result even with no findings"
    assert result[:synthesis], "Should have synthesis section"

    synthesis = result[:synthesis]
    if synthesis
      summary = synthesis["summary"] || synthesis[:summary] || ""
      open_questions = synthesis["open_questions"] || synthesis[:open_questions] || []

      has_indication = summary.downcase.include?("no") ||
                       summary.downcase.include?("could not") ||
                       open_questions.any?
      assert has_indication || result[:findings].empty?,
             "Should indicate no findings were made or have empty findings"
    end
  end
end
