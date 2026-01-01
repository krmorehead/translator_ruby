# frozen_string_literal: true

require "test_helper"

module Planning
  class ProjectPlanFormatterTest < ActiveSupport::TestCase
    def setup
      @milestone1 = Milestone.new(
        number: 1,
        title: "User Authentication",
        description: "Implement secure user login and registration"
      )
      
      @step1_1 = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create User Model",
        intent: "Define the core user entity with authentication fields",
        details: ["Add email and password fields", "Include validation for email uniqueness"],
        tests: ["Test user creation with valid data", "Test email validation"]
      )
      
      @step1_2 = Step.new(
        milestone_number: 1, step_number: 2,
        title: "Add Password Encryption",
        intent: "Secure user passwords using bcrypt",
        details: ["Add bcrypt gem", "Implement password hashing"],
        tests: ["Test password is encrypted", "Test password verification"]
      )
      
      @milestone1.add_step(@step1_1)
      @milestone1.add_step(@step1_2)
      
      @milestone2 = Milestone.new(
        number: 2,
        title: "Session Management",
        description: "Handle user login and logout"
      )
      
      @step2_1 = Step.new(
        milestone_number: 2, step_number: 1,
        title: "Create Sessions Controller",
        intent: "Handle login/logout requests",
        details: ["Add sessions controller", "Implement login action"],
        tests: ["Test successful login", "Test failed login"]
      )
      
      @milestone2.add_step(@step2_1)
    end
    speed_profile :fast
    test "initialization validates input types" do
      formatter = ProjectPlanFormatter.new(
        goal: "Add authentication",
        milestones: [@milestone1]
      )

      assert_equal "Add authentication", formatter.goal
      assert_equal 1, formatter.milestones.size
    end

    speed_profile :fast
    test "validates goal must be String" do
      error = assert_raises(ArgumentError) do
        ProjectPlanFormatter.new(
          goal: 123,
          milestones: []
        )
      end
      assert_match(/goal must be a String/, error.message)
    end

    speed_profile :fast
    test "validates goal cannot be empty" do
      error = assert_raises(ArgumentError) do
        ProjectPlanFormatter.new(
          goal: "  ",
          milestones: []
        )
      end
      assert_match(/goal cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates milestones must be Array" do
      error = assert_raises(ArgumentError) do
        ProjectPlanFormatter.new(
          goal: "Test",
          milestones: "not an array"
        )
      end
      assert_match(/milestones must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all milestones must be Milestone objects" do
      error = assert_raises(TypeError) do
        ProjectPlanFormatter.new(
          goal: "Test",
          milestones: [@milestone1, "not a milestone"]
        )
      end
      assert_match(/all milestones must be Planning::Milestone/, error.message)
    end

    speed_profile :fast
    test "generate with single milestone produces correct structure" do
      formatter = ProjectPlanFormatter.new(
        goal: "Add authentication",
        milestones: [@milestone1]
      )

      markdown = formatter.generate

      assert_includes markdown, "# Project Plan"
      assert_includes markdown, "**Goal**: Add authentication"
      assert_includes markdown, "## Milestone 1: User Authentication"
      assert_includes markdown, "Implement secure user login and registration"
      assert_includes markdown, "### Step 1.1: Create User Model"
      assert_includes markdown, "**Intent**: Define the core user entity with authentication fields"
      assert_includes markdown, "**Details**:"
      assert_includes markdown, "- Add email and password fields"
      assert_includes markdown, "**Tests**:"
      assert_includes markdown, "- Test user creation with valid data"
    end

    speed_profile :fast
    test "generate with multiple milestones produces correct structure" do
      formatter = ProjectPlanFormatter.new(
        goal: "Add authentication system",
        milestones: [@milestone1, @milestone2]
      )

      markdown = formatter.generate

      assert_includes markdown, "## Milestone 1: User Authentication"
      assert_includes markdown, "## Milestone 2: Session Management"
      assert_includes markdown, "### Step 1.1:"
      assert_includes markdown, "### Step 1.2:"
      assert_includes markdown, "### Step 2.1:"
    end

    speed_profile :fast
    test "step formatting includes all sections" do
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [@milestone1]
      )

      markdown = formatter.generate

      assert_includes markdown, "### Step 1.1: Create User Model"
      assert_includes markdown, "**Intent**: Define the core user entity"
      assert_includes markdown, "**Details**:"
      assert_includes markdown, "- Add email and password fields"
      assert_includes markdown, "- Include validation for email uniqueness"
      assert_includes markdown, "**Tests**:"
      assert_includes markdown, "- Test user creation with valid data"
      assert_includes markdown, "- Test email validation"
    end

    speed_profile :fast
    test "numbering is correct for multiple milestones and steps" do
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [@milestone1, @milestone2]
      )

      markdown = formatter.generate

      # Check milestone numbering
      assert_includes markdown, "## Milestone 1:"
      assert_includes markdown, "## Milestone 2:"
      
      # Check step numbering
      assert_includes markdown, "### Step 1.1:"
      assert_includes markdown, "### Step 1.2:"
      assert_includes markdown, "### Step 2.1:"
    end

    speed_profile :fast
    test "horizontal rules appear between steps" do
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [@milestone1]  # Has 2 steps
      )

      markdown = formatter.generate
      
      # Should have a horizontal rule between step 1.1 and 1.2
      assert_includes markdown, "---"
      
      # Count horizontal rules - should be 1 (between 2 steps)
      assert_equal 1, markdown.scan(/^---$/).count
    end

    speed_profile :fast
    test "no horizontal rule after last step in milestone" do
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [@milestone1, @milestone2]
      )

      markdown = formatter.generate
      lines = markdown.split("\n")
      
      # Find the last step (2.1)
      last_step_index = lines.index { |l| l.include?("### Step 2.1:") }
      
      # Check that there's no "---" after the last step's content
      remaining_lines = lines[last_step_index..-1].join("\n")
      
      # There should be no "---" in the remaining content after step 2.1
      # (There's one "---" between step 1.1 and 1.2, so total count is 1)
      assert_equal 1, markdown.scan(/^---$/).count
    end

    speed_profile :fast
    test "markdown renders correctly with proper formatting" do
      formatter = ProjectPlanFormatter.new(
        goal: "Add user authentication",
        milestones: [@milestone1]
      )

      markdown = formatter.generate

      # Check structure
      assert markdown.start_with?("# Project Plan"), "Should start with H1"
      assert_includes markdown, "**Goal**:", "Should have goal marker"
      assert markdown.include?("## Milestone"), "Should have milestone heading"
      assert markdown.include?("### Step"), "Should have step heading"
      assert markdown.include?("**Intent**:"), "Should have intent marker"
      assert markdown.include?("**Details**:"), "Should have details marker"
      assert markdown.include?("**Tests**:"), "Should have tests marker"
    end

    speed_profile :fast
    test "handles Milestone objects with Step objects not hashes" do
      # Verify we're using domain objects
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [@milestone1]
      )

      assert_instance_of Milestone, formatter.milestones.first
      assert_instance_of Step, formatter.milestones.first.steps.first
      
      markdown = formatter.generate
      
      assert_instance_of String, markdown
      assert markdown.length > 0
    end

    speed_profile :fast
    test "empty milestone produces valid markdown" do
      empty_milestone = Milestone.new(
        number: 1,
        title: "Empty Milestone",
        description: "No steps yet"
      )
      
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [empty_milestone]
      )

      markdown = formatter.generate

      assert_includes markdown, "## Milestone 1: Empty Milestone"
      assert_includes markdown, "No steps yet"
      # Should not have any step headings
      refute_includes markdown, "### Step"
    end

    speed_profile :fast
    test "step with empty details shows placeholder" do
      empty_step = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Empty Step",
        intent: "Test step",
        details: [],
        tests: ["Test something"]
      )
      
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test"
      )
      milestone.add_step(empty_step)
      
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [milestone]
      )

      markdown = formatter.generate

      assert_includes markdown, "**Details**:"
      assert_includes markdown, "- _No details provided_"
    end

    speed_profile :fast
    test "step with empty tests shows placeholder" do
      empty_step = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Empty Step",
        intent: "Test step",
        details: ["Some detail"],
        tests: []
      )
      
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test"
      )
      milestone.add_step(empty_step)
      
      formatter = ProjectPlanFormatter.new(
        goal: "Test",
        milestones: [milestone]
      )

      markdown = formatter.generate

      assert_includes markdown, "**Tests**:"
      assert_includes markdown, "- _No tests provided_"
    end

    speed_profile :fast
    test "generates valid markdown structure for complex plan" do
      formatter = ProjectPlanFormatter.new(
        goal: "Build complete authentication system",
        milestones: [@milestone1, @milestone2]
      )

      markdown = formatter.generate

      # Validate structure
      lines = markdown.split("\n")
      
      assert_equal "# Project Plan", lines[0]
      assert lines[2].start_with?("**Goal**:")
      
      # Should have proper hierarchy
      h2_count = markdown.scan(/^## Milestone/).count
      h3_count = markdown.scan(/^### Step/).count
      
      assert_equal 2, h2_count, "Should have 2 milestones"
      assert_equal 3, h3_count, "Should have 3 steps total"
    end
  end
end

