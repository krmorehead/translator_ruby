# frozen_string_literal: true

require "test_helper"

class DiffGenerationServiceTest < ActiveSupport::TestCase
  setup do
    @service = DiffGenerationService.new
  end

  # Basic initialization
  speed_profile :fast
  test "initializes with default options" do
    assert_instance_of DiffGenerationService, @service
  end

  # File creation diffs
  speed_profile :fast
  test "generate_diff for file creation shows all content as additions" do
    new_content = "class Example\n  def test\n    puts 'hello'\n  end\nend\n"
    
    diff = @service.generate_diff(
      file_path: "app/models/example.rb",
      old_content: nil,
      new_content: new_content
    )
    
    assert_instance_of FileDiff, diff
    assert_equal "app/models/example.rb", diff.file_path
    assert_equal :added, diff.change_type
    assert diff.added?
    assert diff.insertions > 0
    assert_equal 0, diff.deletions
    assert_includes diff.diff_content, "+class Example"
    assert_includes diff.diff_content, "+  def test"
    assert_includes diff.diff_content, "+    puts 'hello'"
  end

  speed_profile :fast
  test "generate_diff for file creation with empty old content" do
    new_content = "# New file\n"
    
    diff = @service.generate_diff(
      file_path: "test.rb",
      old_content: "",
      new_content: new_content
    )
    
    assert_instance_of FileDiff, diff
    assert_equal :added, diff.change_type
    assert_includes diff.diff_content, "+# New file"
  end

  # File modification diffs
  speed_profile :fast
  test "generate_diff for file modification shows changes" do
    old_content = "class Example\n  def test\n    puts 'old'\n  end\nend\n"
    new_content = "class Example\n  def test\n    puts 'new'\n  end\nend\n"
    
    diff = @service.generate_diff(
      file_path: "app/models/example.rb",
      old_content: old_content,
      new_content: new_content
    )
    
    assert_instance_of FileDiff, diff
    assert_equal :modified, diff.change_type
    assert diff.modified?
    assert diff.insertions > 0
    assert diff.deletions > 0
    assert_includes diff.diff_content, "-    puts 'old'"
    assert_includes diff.diff_content, "+    puts 'new'"
  end

  speed_profile :fast
  test "generate_diff shows context lines around changes" do
    old_content = "line1\nline2\nline3\nline4\nline5\n"
    new_content = "line1\nline2\nchanged\nline4\nline5\n"
    
    diff = @service.generate_diff(
      file_path: "test.txt",
      old_content: old_content,
      new_content: new_content
    )
    
    assert_instance_of FileDiff, diff
    assert_includes diff.diff_content, "line2", "Should include context before change"
    assert_includes diff.diff_content, "line4", "Should include context after change"
    assert_includes diff.diff_content, "-line3"
    assert_includes diff.diff_content, "+changed"
  end

  # File deletion diffs
  speed_profile :fast
  test "generate_diff for file deletion shows all content as deletions" do
    old_content = "class Example\n  def test\n  end\nend\n"
    
    diff = @service.generate_diff(
      file_path: "app/models/example.rb",
      old_content: old_content,
      new_content: nil
    )
    
    assert_instance_of FileDiff, diff
    assert_equal :deleted, diff.change_type
    assert diff.deleted?
    assert_equal 0, diff.insertions
    assert diff.deletions > 0
    assert_includes diff.diff_content, "-class Example"
    assert_includes diff.diff_content, "-  def test"
  end

  # Diff stats
  speed_profile :fast
  test "diff_stats calculates lines added and removed" do
    old_content = "line1\nline2\nline3"
    new_content = "line1\nmodified\nline3\nnew_line"
    
    diff = @service.generate_diff(
      file_path: "test.txt",
      old_content: old_content,
      new_content: new_content
    )
    
    stats = @service.diff_stats(diff)
    
    # At minimum, we should see additions and removal
    assert stats[:lines_added] >= 1, "Should have at least 1 added line"
    assert stats[:lines_removed] >= 1, "Should have at least 1 removed line"
    assert_equal 1, stats[:files_changed]
  end

  speed_profile :fast
  test "diff_stats handles multiple files in workspace diff" do
    change_set = Execution::ChangeSet.new(
      files: {
        "file1.rb" => {
          change_type: :modified,
          diff: "--- a/file1.rb\n+++ b/file1.rb\n+new line\n-old line\n",
          before_hash: "abc",
          after_hash: "def"
        },
        "file2.rb" => {
          change_type: :created,
          diff: "--- /dev/null\n+++ b/file2.rb\n+first line\n+second line\n",
          before_hash: nil,
          after_hash: "ghi"
        }
      },
      checkpoint_id: "checkpoint1"
    )
    
    workspace_diff = @service.generate_workspace_diff(change_set)
    stats = @service.diff_stats(workspace_diff)
    
    assert_equal 3, stats[:lines_added]    # 1 + 2
    assert_equal 1, stats[:lines_removed]  # 1
    assert_equal 2, stats[:files_changed]  # 2 files with --- headers
  end

  # Workspace diff generation
  speed_profile :fast
  test "generate_workspace_diff combines diffs from ChangeSet" do
    change_set = Execution::ChangeSet.new(
      files: {
        "app/models/example1.rb" => {
          change_type: :modified,
          diff: "--- a/app/models/example1.rb\n+++ b/app/models/example1.rb\n@@ -1,3 +1,3 @@\n class Example1\n-  old\n+  new\n end\n",
          before_hash: "abc",
          after_hash: "def"
        },
        "app/models/example2.rb" => {
          change_type: :created,
          diff: "--- /dev/null\n+++ b/app/models/example2.rb\n@@ -0,0 +1,2 @@\n+class Example2\n+end\n",
          before_hash: nil,
          after_hash: "ghi"
        }
      },
      checkpoint_id: "checkpoint1"
    )
    
    workspace_diff = @service.generate_workspace_diff(change_set)
    
    assert_not_nil workspace_diff
    assert_includes workspace_diff, "app/models/example1.rb"
    assert_includes workspace_diff, "app/models/example2.rb"
    assert_includes workspace_diff, "-  old"
    assert_includes workspace_diff, "+  new"
    assert_includes workspace_diff, "+class Example2"
  end

  speed_profile :fast
  test "generate_workspace_diff handles empty ChangeSet" do
    change_set = Execution::ChangeSet.new(
      files: {},
      checkpoint_id: "checkpoint1"
    )
    
    workspace_diff = @service.generate_workspace_diff(change_set)
    
    assert_equal "", workspace_diff
  end

  # Options: context_lines
  speed_profile :fast
  test "generate_diff respects context_lines option" do
    old_content = "line1\nline2\nline3\nline4\nline5\nline6\nline7\n"
    new_content = "line1\nline2\nline3\nchanged\nline5\nline6\nline7\n"
    
    # Default context (3 lines)
    diff_default = @service.generate_diff(
      file_path: "test.txt",
      old_content: old_content,
      new_content: new_content
    )
    
    # Minimal context (1 line)
    diff_minimal = @service.generate_diff(
      file_path: "test.txt",
      old_content: old_content,
      new_content: new_content,
      context_lines: 1
    )
    
    # Minimal diff should be shorter
    assert_instance_of FileDiff, diff_default
    assert_instance_of FileDiff, diff_minimal
    assert diff_minimal.diff_content.length < diff_default.diff_content.length
  end

  # Format for display
  speed_profile :fast
  test "format_for_display returns markdown formatted diff" do
    diff = "+new line\n-old line\n context\n"
    
    formatted = @service.format_for_display(diff, format: :markdown)
    
    assert_includes formatted, "```diff"
    assert_includes formatted, "+new line"
    assert_includes formatted, "-old line"
    assert_includes formatted, "```"
  end

  speed_profile :fast
  test "format_for_display returns HTML formatted diff with colors" do
    diff = "+new line\n-old line\n context\n"
    
    formatted = @service.format_for_display(diff, format: :html)
    
    assert_includes formatted, "<pre>"
    assert_includes formatted, "<span", "Should wrap lines in spans"
    # Should have some styling for additions/deletions
    assert_match(/style.*color/, formatted)
  end

  speed_profile :fast
  test "format_for_display returns plain text by default" do
    diff = "+new line\n-old line\n"
    
    formatted = @service.format_for_display(diff, format: :plain)
    
    assert_equal diff, formatted
  end

  # Edge cases
  speed_profile :fast
  test "generate_diff handles identical content" do
    content = "unchanged\n"
    
    diff = @service.generate_diff(
      file_path: "test.txt",
      old_content: content,
      new_content: content
    )
    
    # No changes, should return FileDiff with no insertions/deletions
    assert_instance_of FileDiff, diff
    assert_equal 0, diff.insertions
    assert_equal 0, diff.deletions
    refute_includes diff.diff_content, "+"
    refute_includes diff.diff_content, "-"
  end

  speed_profile :fast
  test "generate_diff handles empty files" do
    diff = @service.generate_diff(
      file_path: "empty.txt",
      old_content: "",
      new_content: ""
    )
    
    assert_instance_of FileDiff, diff
    assert_equal :added, diff.change_type
  end

  speed_profile :fast
  test "generate_diff handles binary files gracefully" do
    old_content = "\x00\x01\x02\xFF"
    new_content = "\x00\x01\xFF\xFE"
    
    diff = @service.generate_diff(
      file_path: "binary.bin",
      old_content: old_content,
      new_content: new_content
    )
    
    # Should return FileDiff with is_binary flag
    assert_instance_of FileDiff, diff
    assert diff.is_binary, "Should be marked as binary"
    assert_includes diff.diff_content.downcase, "binary"
  end

  # Validation
  speed_profile :fast
  test "generate_diff requires file_path" do
    error = assert_raises(ArgumentError) do
      @service.generate_diff(
        file_path: nil,
        old_content: "old",
        new_content: "new"
      )
    end
    
    assert_match(/file_path.*required/i, error.message)
  end

  speed_profile :fast
  test "generate_diff allows deletion with nil new_content" do
    diff = @service.generate_diff(
      file_path: "test.txt",
      old_content: "old content",
      new_content: nil
    )
    
    # Deletion should work - should return a FileDiff showing file deleted
    assert_instance_of FileDiff, diff
    assert_equal :deleted, diff.change_type
    assert_includes diff.diff_content, "-old content"
  end

  speed_profile :fast
  test "generate_workspace_diff requires ChangeSet" do
    error = assert_raises(ArgumentError) do
      @service.generate_workspace_diff(nil)
    end
    
    assert_match(/change_set.*required/i, error.message)
  end

  speed_profile :fast
  test "generate_workspace_diff validates ChangeSet type" do
    error = assert_raises(TypeError) do
      @service.generate_workspace_diff({})
    end
    
    assert_match(/must be.*ChangeSet/i, error.message)
  end
end

