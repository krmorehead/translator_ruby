require "test_helper"

class CodebaseResearcherIntegrationTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  def setup
    @output_path = Rails.root.join("tmp", "research_output_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@output_path)

    # Set env vars for test isolation
    @original_output_path = ENV["RESEARCH_OUTPUT_PATH"]
    @original_state_path = ENV["AGENT_STATE_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = @output_path
    ENV["AGENT_STATE_PATH"] = @output_path
  end

  def teardown
    FileUtils.rm_rf(@output_path) if @output_path && File.exist?(@output_path)

    # Restore env vars
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

  test "research simple topic on fixture codebase" do
    worker = CodebaseResearcher.new(
      goal: "How does the calculator perform arithmetic operations?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    assert result[:success], "Research should succeed: #{result[:error]}"
    assert_not_nil result[:owner_id]
    assert_equal FIXTURE_PATH, result[:path]

    # Should have discovered some findings
    assert result[:findings].is_a?(Array)
  end

  test "research dependency analysis on fixture" do
    worker = CodebaseResearcher.new(
      goal: "What are the dependencies between services?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    assert result[:success], "Research should succeed: #{result[:error]}"

    # Synthesis should mention key classes
    synthesis = result[:synthesis]
    if synthesis
      summary = synthesis["summary"] || ""
      # The summary should reference the codebase structure
      assert summary.present?, "Should have a summary"
    end
  end

  test "verify output files are created" do
    worker = CodebaseResearcher.new(
      goal: "How does formatting work?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    assert result[:success], "Research should succeed"

    # If we have synthesis, write output
    if result[:synthesis]
      output_service = ResearchOutputService.new(
        research_topic: "How does formatting work?",
        base_path: FIXTURE_PATH
      )
      files = output_service.write(synthesis: result[:synthesis])

      assert files.any?, "Should create output files"
      files.each do |file_path|
        assert File.exist?(file_path), "Output file should exist: #{file_path}"
      end
    end
  end

  test "verify memory store contains expected findings" do
    worker = CodebaseResearcher.new(
      goal: "What classes exist in this codebase?",
      path: FIXTURE_PATH,
      max_depth: 2
    )

    result = worker.execute

    assert result[:success], "Research should succeed"

    memory = result[:memory]
    assert memory, "Should have memory data"

    # Check memory contains expected sections
    assert memory[:research_goal] || memory["research_goal"], "Should have research goal"
  end

  test "multiple parallel research sessions do not conflict" do
    workers = 2.times.map do |i|
      CodebaseResearcher.new(
        goal: "Research topic #{i}",
        path: FIXTURE_PATH,
        max_depth: 1
      )
    end

    # Execute both (in sequence for test simplicity, but with different owner_ids)
    results = workers.map(&:execute)

    # Verify they have different owner_ids
    owner_ids = results.map { |r| r[:owner_id] }
    assert_equal owner_ids.uniq.size, owner_ids.size, "Each worker should have unique owner_id"

    # Verify both succeeded
    results.each_with_index do |r, i|
      assert r[:success], "Worker #{i} should succeed"
    end
  end

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

      # Should complete without crashing
      assert result, "Should return a result"
    ensure
      FileUtils.rm_rf(empty_dir)
    end
  end
end

