# frozen_string_literal: true

require "test_helper"

module ProjectPlanner
  class ResultTest < ActiveSupport::TestCase
    def setup
      @milestone = Planning::Milestone.new(
        number: 1,
        title: "Setup",
        description: "Initial setup"
      )
      
      @milestone.add_step(Planning::Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create Database",
        intent: "Setup data storage",
        details: ["Configure PostgreSQL"],
        tests: ["Test connection"]
      ))

      @planning_result = Planning::Result.new(
        goal: "Add authentication",
        project_name: "user_auth",
        milestones: [@milestone],
        existing_files: [],
        planned_files: [],
        file_references_content: "# File References",
        project_plan_content: "# Project Plan"
      )
    end
    speed_profile :fast
    test "initialization with success result" do
      result = Result.new(
        success: true,
        goal: "Add authentication",
        path: "/path/to/project",
        project_name: "user_auth",
        owner_id: "abc123",
        planning_result: @planning_result,
        project_path: "/path/to/docs",
        file_references_path: "/path/to/docs/file_references.md",
        project_plan_path: "/path/to/docs/project_plan.md",
        research_summary: "Found 5 files",
        metadata: { max_depth: 2 }
      )

      assert result.success?
      refute result.failed?
      assert_equal "Add authentication", result.goal
      assert_equal "/path/to/project", result.path
      assert_equal "user_auth", result.project_name
      assert_equal "abc123", result.owner_id
      assert_equal @planning_result, result.planning_result
      assert_equal "/path/to/docs", result.project_path
      assert_nil result.error
    end

    speed_profile :fast
    test "initialization with failure result" do
      result = Result.new(
        success: false,
        goal: "Add authentication",
        path: "/path/to/project",
        project_name: "user_auth",
        owner_id: "abc123",
        error: "Research workflow failed",
        metadata: { final_state: :failed }
      )

      refute result.success?
      assert result.failed?
      assert_equal "Research workflow failed", result.error
      assert_nil result.planning_result
      assert_nil result.project_path
    end

    speed_profile :fast
    test "validates success must be Boolean" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: "true",
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123"
        )
      end
      assert_match(/success must be a Boolean/, error.message)
    end

    speed_profile :fast
    test "validates goal must be String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: 123,
          path: "/path",
          project_name: "test",
          owner_id: "123"
        )
      end
      assert_match(/goal must be a String/, error.message)
    end

    speed_profile :fast
    test "validates goal cannot be empty" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "  ",
          path: "/path",
          project_name: "test",
          owner_id: "123"
        )
      end
      assert_match(/goal cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates path must be String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: 123,
          project_name: "test",
          owner_id: "123"
        )
      end
      assert_match(/path must be a String/, error.message)
    end

    speed_profile :fast
    test "validates path cannot be empty" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "  ",
          project_name: "test",
          owner_id: "123"
        )
      end
      assert_match(/path cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates project_name must be String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: 123,
          owner_id: "123"
        )
      end
      assert_match(/project_name must be a String/, error.message)
    end

    speed_profile :fast
    test "validates project_name cannot be empty" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: "  ",
          owner_id: "123"
        )
      end
      assert_match(/project_name cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates owner_id must be String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: 123
        )
      end
      assert_match(/owner_id must be a String/, error.message)
    end

    speed_profile :fast
    test "validates owner_id cannot be empty" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "  "
        )
      end
      assert_match(/owner_id cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates planning_result must be Planning::Result or nil" do
      error = assert_raises(TypeError) do
        Result.new(
          success: true,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123",
          planning_result: "not a result"
        )
      end
      assert_match(/planning_result must be a Planning::Result or nil/, error.message)
    end

    speed_profile :fast
    test "validates error must be String or nil" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123",
          error: 123
        )
      end
      assert_match(/error must be a String or nil/, error.message)
    end

    speed_profile :fast
    test "validates metadata must be Hash" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123",
          metadata: "not a hash"
        )
      end
      assert_match(/metadata must be a Hash/, error.message)
    end

    speed_profile :fast
    test "validates cannot have both success=true and error present" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: true,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123",
          planning_result: @planning_result,
          error: "some error"
        )
      end
      assert_match(/Cannot have both success=true and error present/, error.message)
    end

    speed_profile :fast
    test "validates success=true requires planning_result" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: true,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123"
        )
      end
      assert_match(/success=true requires planning_result/, error.message)
    end

    speed_profile :fast
    test "validates success=false should not have planning_result" do
      error = assert_raises(ArgumentError) do
        Result.new(
          success: false,
          goal: "Test",
          path: "/path",
          project_name: "test",
          owner_id: "123",
          planning_result: @planning_result
        )
      end
      assert_match(/success=false should not have planning_result/, error.message)
    end

    speed_profile :fast
    test "success? returns true for successful result" do
      result = Result.new(
        success: true,
        goal: "Test",
        path: "/path",
        project_name: "test",
        owner_id: "123",
        planning_result: @planning_result
      )

      assert result.success?
    end

    speed_profile :fast
    test "failed? returns true for failed result" do
      result = Result.new(
        success: false,
        goal: "Test",
        path: "/path",
        project_name: "test",
        owner_id: "123",
        error: "Failed"
      )

      assert result.failed?
    end

    speed_profile :fast
    test "to_h produces correct hash structure for success" do
      result = Result.new(
        success: true,
        goal: "Add auth",
        path: "/path/to/project",
        project_name: "user_auth",
        owner_id: "abc123",
        planning_result: @planning_result,
        project_path: "/path/to/docs",
        file_references_path: "/path/to/docs/file_references.md",
        project_plan_path: "/path/to/docs/project_plan.md",
        research_summary: "Found 5 files",
        metadata: { max_depth: 2 }
      )

      hash = result.to_h

      assert_equal true, hash[:success]
      assert_equal "Add auth", hash[:goal]
      assert_equal "/path/to/project", hash[:path]
      assert_equal "user_auth", hash[:project_name]
      assert_equal "abc123", hash[:owner_id]
      assert_equal "/path/to/docs", hash[:project_path]
      assert_equal 1, hash[:milestones].size
      assert hash[:milestones].first.is_a?(Hash)
      assert_nil hash[:error]
    end

    speed_profile :fast
    test "to_h produces correct hash structure for failure" do
      result = Result.new(
        success: false,
        goal: "Add auth",
        path: "/path/to/project",
        project_name: "user_auth",
        owner_id: "abc123",
        error: "Research failed",
        metadata: { final_state: :failed }
      )

      hash = result.to_h

      assert_equal false, hash[:success]
      assert_equal "Research failed", hash[:error]
      assert_equal [], hash[:milestones]
      assert_equal [], hash[:existing_files]
      assert_equal [], hash[:planned_files]
    end

    speed_profile :fast
    test "from_h reconstructs success result correctly with symbol keys" do
      original = Result.new(
        success: true,
        goal: "Add auth",
        path: "/path",
        project_name: "user_auth",
        owner_id: "abc123",
        planning_result: @planning_result,
        project_path: "/path/to/docs",
        research_summary: "Found files"
      )

      # Need to manually create hash with planning_result for reconstruction
      hash = {
        success: true,
        goal: "Add auth",
        path: "/path",
        project_name: "user_auth",
        owner_id: "abc123",
        planning_result: @planning_result.to_h,
        project_path: "/path/to/docs",
        research_summary: "Found files",
        metadata: {}
      }

      reconstructed = Result.from_h(hash)

      assert_equal original.success, reconstructed.success
      assert_equal original.goal, reconstructed.goal
      assert_equal original.path, reconstructed.path
      assert_instance_of Planning::Result, reconstructed.planning_result
    end

    speed_profile :fast
    test "from_h reconstructs failure result correctly with string keys" do
      hash = {
        "success" => false,
        "goal" => "Add auth",
        "path" => "/path",
        "project_name" => "user_auth",
        "owner_id" => "abc123",
        "error" => "Failed",
        "metadata" => {}
      }

      reconstructed = Result.from_h(hash)

      assert_equal false, reconstructed.success
      assert_equal "Add auth", reconstructed.goal
      assert_equal "Failed", reconstructed.error
      assert_nil reconstructed.planning_result
    end

    speed_profile :fast
    test "handles nil planning_result for failures" do
      result = Result.new(
        success: false,
        goal: "Test",
        path: "/path",
        project_name: "test",
        owner_id: "123",
        error: "Failed"
      )

      assert_nil result.planning_result
      assert result.failed?
      assert_equal "Failed", result.error
    end

    speed_profile :fast
    test "serialization includes planning data when present" do
      result = Result.new(
        success: true,
        goal: "Test",
        path: "/path",
        project_name: "test",
        owner_id: "123",
        planning_result: @planning_result
      )

      hash = result.to_h

      assert hash[:milestones].any?
      assert_equal 1, hash[:milestones].size
    end

    speed_profile :fast
    test "serialization includes empty arrays when planning_result nil" do
      result = Result.new(
        success: false,
        goal: "Test",
        path: "/path",
        project_name: "test",
        owner_id: "123",
        error: "Failed"
      )

      hash = result.to_h

      assert_equal [], hash[:milestones]
      assert_equal [], hash[:existing_files]
      assert_equal [], hash[:planned_files]
    end
  end
end

