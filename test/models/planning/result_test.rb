# frozen_string_literal: true

require "test_helper"

module Planning
  class ResultTest < ActiveSupport::TestCase
    def setup
      @milestone = Milestone.new(
        number: 1,
        title: "Setup Infrastructure",
        description: "Initialize project structure"
      )
      
      @milestone.add_step(Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create Database",
        intent: "Setup data storage",
        details: ["Configure PostgreSQL"],
        tests: ["Test connection"]
      ))

      @existing_file = FileReference.new(
        path: "app/models/user.rb",
        description: "User model",
        relevance: "Auth logic"
      )

      @planned_file = FileReference.new(
        path: "app/services/auth_service.rb",
        description: "Auth service",
        created_in_step: "1.1"
      )
    end
    speed_profile :fast
    test "initialization with all required attributes" do
      result = Result.new(
        goal: "Add authentication",
        project_name: "user_auth",
        milestones: [@milestone],
        existing_files: [@existing_file],
        planned_files: [@planned_file],
        file_references_content: "# File References",
        project_plan_content: "# Project Plan"
      )

      assert_equal "Add authentication", result.goal
      assert_equal "user_auth", result.project_name
      assert_equal 1, result.milestones.size
      assert_equal 1, result.existing_files.size
      assert_equal 1, result.planned_files.size
      assert_equal "# File References", result.file_references_content
      assert_equal "# Project Plan", result.project_plan_content
    end

    speed_profile :fast
    test "validates goal must be a String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: 123,
          project_name: "test",
          milestones: [],
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/goal must be a String/, error.message)
    end

    speed_profile :fast
    test "validates goal cannot be empty" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "  ",
          project_name: "test",
          milestones: [],
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/goal cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates project_name must be a String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: 123,
          milestones: [],
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/project_name must be a String/, error.message)
    end

    speed_profile :fast
    test "validates project_name cannot be empty" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: "  ",
          milestones: [],
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/project_name cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates milestones must be an Array" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: "not an array",
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/milestones must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all milestones must be Milestone objects" do
      error = assert_raises(TypeError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [@milestone, "not a milestone"],
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/all milestones must be Planning::Milestone/, error.message)
    end

    speed_profile :fast
    test "validates existing_files must be an Array" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [],
          existing_files: "not an array",
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/existing_files must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all existing_files must be FileReference objects" do
      error = assert_raises(TypeError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [],
          existing_files: [@existing_file, "not a file ref"],
          planned_files: [],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/all existing_files must be Planning::FileReference/, error.message)
    end

    speed_profile :fast
    test "validates planned_files must be an Array" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [],
          existing_files: [],
          planned_files: "not an array",
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/planned_files must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all planned_files must be FileReference objects" do
      error = assert_raises(TypeError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [],
          existing_files: [],
          planned_files: [@planned_file, "not a file ref"],
          file_references_content: "",
          project_plan_content: ""
        )
      end
      assert_match(/all planned_files must be Planning::FileReference/, error.message)
    end

    speed_profile :fast
    test "validates file_references_content must be a String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [],
          existing_files: [],
          planned_files: [],
          file_references_content: 123,
          project_plan_content: ""
        )
      end
      assert_match(/file_references_content must be a String/, error.message)
    end

    speed_profile :fast
    test "validates project_plan_content must be a String" do
      error = assert_raises(ArgumentError) do
        Result.new(
          goal: "Test goal",
          project_name: "test",
          milestones: [],
          existing_files: [],
          planned_files: [],
          file_references_content: "",
          project_plan_content: 123
        )
      end
      assert_match(/project_plan_content must be a String/, error.message)
    end

    speed_profile :fast
    test "milestone_count returns correct value" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone],
        existing_files: [],
        planned_files: [],
        file_references_content: "",
        project_plan_content: ""
      )

      assert_equal 1, result.milestone_count
    end

    speed_profile :fast
    test "step_count returns total across all milestones" do
      milestone2 = Milestone.new(
        number: 2,
        title: "Second Milestone",
        description: "More work"
      )
      
      milestone2.add_step(Step.new(
        milestone_number: 2, step_number: 1,
        title: "Step 2.1",
        intent: "Do something",
        details: ["Detail"],
        tests: ["Test"]
      ))
      
      milestone2.add_step(Step.new(
        milestone_number: 2, step_number: 2,
        title: "Step 2.2",
        intent: "Do more",
        details: ["Detail"],
        tests: ["Test"]
      ))

      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone, milestone2],
        existing_files: [],
        planned_files: [],
        file_references_content: "",
        project_plan_content: ""
      )

      assert_equal 3, result.step_count  # 1 from milestone + 2 from milestone2
    end

    speed_profile :fast
    test "file_count returns sum of existing and planned files" do
      existing_file2 = FileReference.new(
        path: "app/models/post.rb",
        description: "Post model",
        relevance: "Content"
      )

      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [],
        existing_files: [@existing_file, existing_file2],
        planned_files: [@planned_file],
        file_references_content: "",
        project_plan_content: ""
      )

      assert_equal 3, result.file_count
    end

    speed_profile :fast
    test "success? returns true when has milestones and content" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone],
        existing_files: [],
        planned_files: [],
        file_references_content: "# File References",
        project_plan_content: "# Project Plan"
      )

      assert result.success?
    end

    speed_profile :fast
    test "success? returns false when no milestones" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [],
        existing_files: [],
        planned_files: [],
        file_references_content: "# File References",
        project_plan_content: "# Project Plan"
      )

      refute result.success?
    end

    speed_profile :fast
    test "success? returns false when missing file_references_content" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone],
        existing_files: [],
        planned_files: [],
        file_references_content: "",
        project_plan_content: "# Project Plan"
      )

      refute result.success?
    end

    speed_profile :fast
    test "success? returns false when missing project_plan_content" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone],
        existing_files: [],
        planned_files: [],
        file_references_content: "# File References",
        project_plan_content: ""
      )

      refute result.success?
    end

    speed_profile :fast
    test "to_h produces correct hash structure" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone],
        existing_files: [@existing_file],
        planned_files: [@planned_file],
        file_references_content: "# File References",
        project_plan_content: "# Project Plan"
      )

      hash = result.to_h

      assert_equal "Test goal", hash[:goal]
      assert_equal "test", hash[:project_name]
      assert_equal 1, hash[:milestones].size
      assert hash[:milestones].first.is_a?(Hash)
      assert_equal 1, hash[:existing_files].size
      assert_equal 1, hash[:planned_files].size
      assert_equal "# File References", hash[:file_references_content]
      assert_equal "# Project Plan", hash[:project_plan_content]
    end

    speed_profile :fast
    test "from_h reconstructs nested objects correctly with symbol keys" do
      original = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [@milestone],
        existing_files: [@existing_file],
        planned_files: [@planned_file],
        file_references_content: "# File References",
        project_plan_content: "# Project Plan"
      )

      hash = original.to_h
      reconstructed = Result.from_h(**hash)

      assert_equal original.goal, reconstructed.goal
      assert_equal original.project_name, reconstructed.project_name
      assert_equal original.milestone_count, reconstructed.milestone_count
      assert_instance_of Milestone, reconstructed.milestones.first
      assert_instance_of FileReference, reconstructed.existing_files.first
      assert_instance_of FileReference, reconstructed.planned_files.first
    end

    speed_profile :fast
    test "from_h reconstructs nested objects correctly with string keys" do
      hash = {
        "id" => SecureRandom.uuid,
        "goal" => "Test goal",
        "project_name" => "test",
        "milestones" => [
          {
            "number" => 1,
            "title" => "Milestone",
            "description" => "Description",
            "steps" => []
          }
        ],
        "existing_files" => [
          {
            "path" => "app/models/user.rb",
            "description" => "User model",
            "relevance" => "Auth"
          }
        ],
        "planned_files" => [],
        "file_references_content" => "# File References",
        "project_plan_content" => "# Project Plan"
      }

      reconstructed = Result.from_h(**hash.deep_symbolize_keys)

      assert_equal "Test goal", reconstructed.goal
      assert_equal "test", reconstructed.project_name
      assert_instance_of Milestone, reconstructed.milestones.first
      assert_instance_of FileReference, reconstructed.existing_files.first
    end

    speed_profile :fast
    test "handles empty collections gracefully" do
      result = Result.new(
        goal: "Test goal",
        project_name: "test",
        milestones: [],
        existing_files: [],
        planned_files: [],
        file_references_content: "",
        project_plan_content: ""
      )

      assert_equal 0, result.milestone_count
      assert_equal 0, result.step_count
      assert_equal 0, result.file_count
      refute result.success?
    end

    speed_profile :fast
    test "serialization round-trip preserves nested domain objects" do
      original = Result.new(
        goal: "Add payment processing",
        project_name: "payments",
        milestones: [@milestone],
        existing_files: [@existing_file],
        planned_files: [@planned_file],
        file_references_content: "# File References\n\nSome content",
        project_plan_content: "# Project Plan\n\nMore content"
      )

      hash = original.to_h
      reconstructed = Result.from_h(**hash)

      # Verify domain objects are reconstructed, not hashes
      assert_instance_of Milestone, reconstructed.milestones.first
      assert_instance_of FileReference, reconstructed.existing_files.first
      assert_instance_of FileReference, reconstructed.planned_files.first
      
      # Verify data integrity
      assert_equal original.goal, reconstructed.goal
      assert_equal original.project_name, reconstructed.project_name
      assert_equal original.milestone_count, reconstructed.milestone_count
      assert_equal original.file_references_content, reconstructed.file_references_content
      assert_equal original.project_plan_content, reconstructed.project_plan_content
    end
  end
end

