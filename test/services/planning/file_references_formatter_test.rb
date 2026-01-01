# frozen_string_literal: true

require "test_helper"

module Planning
  class FileReferencesFormatterTest < ActiveSupport::TestCase
    def setup
      @existing_file1 = FileReference.new(
        path: "app/models/user.rb",
        description: "User model with authentication",
        relevance: "Contains auth logic"
      )

      @existing_file2 = FileReference.new(
        path: "app/controllers/sessions_controller.rb",
        description: "Session management controller",
        relevance: "Handles login/logout"
      )

      @planned_file1 = FileReference.new(
        path: "app/services/auth_service.rb",
        description: "Authentication service",
        created_in_step: "2.1"
      )

      @planned_file2 = FileReference.new(
        path: "test/services/auth_service_test.rb",
        description: "Tests for auth service",
        created_in_step: "2.1"
      )
    end
    speed_profile :fast
    test "initialization validates input types" do
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1],
        planned_files: [@planned_file1]
      )

      assert_equal 1, formatter.existing_files.size
      assert_equal 1, formatter.planned_files.size
    end

    speed_profile :fast
    test "validates existing_files must be Array" do
      error = assert_raises(ArgumentError) do
        FileReferencesFormatter.new(
          existing_files: "not an array",
          planned_files: []
        )
      end
      assert_match(/existing_files must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates planned_files must be Array" do
      error = assert_raises(ArgumentError) do
        FileReferencesFormatter.new(
          existing_files: [],
          planned_files: "not an array"
        )
      end
      assert_match(/planned_files must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all existing_files must be FileReference objects" do
      error = assert_raises(TypeError) do
        FileReferencesFormatter.new(
          existing_files: [@existing_file1, "not a file ref"],
          planned_files: []
        )
      end
      assert_match(/all existing_files must be Planning::FileReference/, error.message)
    end

    speed_profile :fast
    test "validates all planned_files must be FileReference objects" do
      error = assert_raises(TypeError) do
        FileReferencesFormatter.new(
          existing_files: [],
          planned_files: [@planned_file1, "not a file ref"]
        )
      end
      assert_match(/all planned_files must be Planning::FileReference/, error.message)
    end

    speed_profile :fast
    test "generate with existing files produces correct markdown" do
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1, @existing_file2],
        planned_files: []
      )

      markdown = formatter.generate

      assert_includes markdown, "# File References"
      assert_includes markdown, "## Existing Files"
      assert_includes markdown, "| File Path | Description | Relevance |"
      assert_includes markdown, "| `app/models/user.rb` | User model with authentication | Contains auth logic |"
      assert_includes markdown, "| `app/controllers/sessions_controller.rb` | Session management controller | Handles login/logout |"
      assert_includes markdown, "## Planned Files"
      assert_includes markdown, "_No new files planned._"
    end

    speed_profile :fast
    test "generate with planned files produces correct markdown" do
      formatter = FileReferencesFormatter.new(
        existing_files: [],
        planned_files: [@planned_file1, @planned_file2]
      )

      markdown = formatter.generate

      assert_includes markdown, "# File References"
      assert_includes markdown, "## Planned Files"
      assert_includes markdown, "| File Path | Description | Created In |"
      assert_includes markdown, "| `app/services/auth_service.rb` | Authentication service | 2.1 |"
      assert_includes markdown, "| `test/services/auth_service_test.rb` | Tests for auth service | 2.1 |"
      assert_includes markdown, "## Existing Files"
      assert_includes markdown, "_No existing files identified._"
    end

    speed_profile :fast
    test "generate with both types produces complete markdown" do
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1],
        planned_files: [@planned_file1]
      )

      markdown = formatter.generate

      assert_includes markdown, "# File References"
      assert_includes markdown, "## Existing Files"
      assert_includes markdown, "| `app/models/user.rb` |"
      assert_includes markdown, "## Planned Files"
      assert_includes markdown, "| `app/services/auth_service.rb` |"
      refute_includes markdown, "_No existing files"
      refute_includes markdown, "_No new files"
    end

    speed_profile :fast
    test "generate with empty inputs produces sensible output" do
      formatter = FileReferencesFormatter.new(
        existing_files: [],
        planned_files: []
      )

      markdown = formatter.generate

      assert_includes markdown, "# File References"
      assert_includes markdown, "## Existing Files"
      assert_includes markdown, "_No existing files identified._"
      assert_includes markdown, "## Planned Files"
      assert_includes markdown, "_No new files planned._"
    end

    speed_profile :fast
    test "markdown format matches expected structure" do
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1],
        planned_files: [@planned_file1]
      )

      markdown = formatter.generate
      lines = markdown.split("\n")

      assert_equal "# File References", lines[0]
      assert_equal "", lines[1]
      assert_equal "## Existing Files", lines[2]
      assert_equal "", lines[3]
      assert_equal "| File Path | Description | Relevance |", lines[4]
      assert_equal "|-----------|-------------|-----------|", lines[5]
    end

    speed_profile :fast
    test "handles FileReference objects not hashes" do
      # Create formatter with domain objects
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1],
        planned_files: [@planned_file1]
      )

      markdown = formatter.generate

      # Should successfully generate markdown from objects
      assert_instance_of String, markdown
      assert markdown.length > 0
      assert_includes markdown, @existing_file1.path
      assert_includes markdown, @planned_file1.path
    end

    speed_profile :fast
    test "existing files table includes all required columns" do
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1],
        planned_files: []
      )

      markdown = formatter.generate

      # Check table header
      assert_includes markdown, "| File Path | Description | Relevance |"
      assert_includes markdown, "|-----------|-------------|-----------|"
      
      # Check data row with all fields
      assert_includes markdown, "`#{@existing_file1.path}`"
      assert_includes markdown, @existing_file1.description
      assert_includes markdown, @existing_file1.relevance
    end

    speed_profile :fast
    test "planned files table includes all required columns" do
      formatter = FileReferencesFormatter.new(
        existing_files: [],
        planned_files: [@planned_file1]
      )

      markdown = formatter.generate

      # Check table header
      assert_includes markdown, "| File Path | Description | Created In |"
      assert_includes markdown, "|-----------|-------------|------------|"
      
      # Check data row with all fields
      assert_includes markdown, "`#{@planned_file1.path}`"
      assert_includes markdown, @planned_file1.description
      assert_includes markdown, @planned_file1.created_in_step
    end

    speed_profile :fast
    test "generates valid markdown that can be parsed" do
      formatter = FileReferencesFormatter.new(
        existing_files: [@existing_file1, @existing_file2],
        planned_files: [@planned_file1, @planned_file2]
      )

      markdown = formatter.generate

      # Basic markdown validation
      assert markdown.include?("# File References"), "Should have H1 heading"
      assert markdown.include?("## Existing Files"), "Should have H2 heading for existing"
      assert markdown.include?("## Planned Files"), "Should have H2 heading for planned"
      assert markdown.scan(/\|/).count >= 12, "Should have table separators"
    end
  end
end

