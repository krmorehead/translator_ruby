# frozen_string_literal: true

require "test_helper"

class FileDiffTest < ActiveSupport::TestCase
  # Initialization tests
  speed_profile :fast
  test "initializes with required parameters" do
    diff = FileDiff.new(
      file_path: "app/models/user.rb",
      change_type: :modified
    )

    assert_equal "app/models/user.rb", diff.file_path
    assert_equal :modified, diff.change_type
    assert_equal 0, diff.insertions
    assert_equal 0, diff.deletions
    assert_nil diff.diff_content
    refute diff.is_binary
  end

  speed_profile :fast
  test "initializes with all parameters" do
    diff_content = "--- a/file.rb\n+++ b/file.rb\n@@ -1,3 +1,4 @@\n"
    diff = FileDiff.new(
      file_path: "app/models/user.rb",
      change_type: :modified,
      insertions: 5,
      deletions: 3,
      diff_content: diff_content,
      is_binary: false
    )

    assert_equal "app/models/user.rb", diff.file_path
    assert_equal :modified, diff.change_type
    assert_equal 5, diff.insertions
    assert_equal 3, diff.deletions
    assert_equal diff_content, diff.diff_content
    refute diff.is_binary
  end

  # Validation tests
  speed_profile :fast
  test "validates file_path is a String" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: 123,
        change_type: :modified
      )
    end
    assert_match(/file_path must be a String/, error.message)
  end

  speed_profile :fast
  test "validates file_path is not empty" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "",
        change_type: :modified
      )
    end
    assert_match(/file_path cannot be empty/, error.message)
  end

  speed_profile :fast
  test "validates change_type is a Symbol" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: "modified"
      )
    end
    assert_match(/change_type must be a Symbol/, error.message)
  end

  speed_profile :fast
  test "validates change_type is valid" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: :invalid
      )
    end
    assert_match(/Invalid change_type: invalid/, error.message)
  end

  speed_profile :fast
  test "validates insertions is an Integer" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: :modified,
        insertions: "5"
      )
    end
    assert_match(/insertions must be an Integer/, error.message)
  end

  speed_profile :fast
  test "validates insertions is not negative" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: :modified,
        insertions: -1
      )
    end
    assert_match(/insertions cannot be negative/, error.message)
  end

  speed_profile :fast
  test "validates deletions is an Integer" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: :modified,
        deletions: "3"
      )
    end
    assert_match(/deletions must be an Integer/, error.message)
  end

  speed_profile :fast
  test "validates deletions is not negative" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: :modified,
        deletions: -1
      )
    end
    assert_match(/deletions cannot be negative/, error.message)
  end

  speed_profile :fast
  test "validates is_binary is a Boolean" do
    error = assert_raises(ArgumentError) do
      FileDiff.new(
        file_path: "file.rb",
        change_type: :modified,
        is_binary: "true"
      )
    end
    assert_match(/is_binary must be a Boolean/, error.message)
  end

  # Helper methods tests
  speed_profile :fast
  test "changed? returns true when insertions exist" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified,
      insertions: 5
    )

    assert diff.changed?
  end

  speed_profile :fast
  test "changed? returns true when deletions exist" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified,
      deletions: 3
    )

    assert diff.changed?
  end

  speed_profile :fast
  test "changed? returns false when no changes" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified
    )

    refute diff.changed?
  end

  speed_profile :fast
  test "lines_changed returns sum of insertions and deletions" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified,
      insertions: 5,
      deletions: 3
    )

    assert_equal 8, diff.lines_changed
  end

  speed_profile :fast
  test "change_summary returns formatted summary" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified,
      insertions: 5,
      deletions: 3
    )

    assert_equal "+5 -3", diff.change_summary
  end

  speed_profile :fast
  test "change_summary returns Binary file for binary files" do
    diff = FileDiff.new(
      file_path: "image.png",
      change_type: :modified,
      is_binary: true
    )

    assert_equal "Binary file", diff.change_summary
  end

  speed_profile :fast
  test "change_summary returns No changes when no changes" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified
    )

    assert_equal "No changes", diff.change_summary
  end

  # Change type predicates
  speed_profile :fast
  test "added? returns true for added files" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :added
    )

    assert diff.added?
    refute diff.modified?
    refute diff.deleted?
  end

  speed_profile :fast
  test "modified? returns true for modified files" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :modified
    )

    refute diff.added?
    assert diff.modified?
    refute diff.deleted?
  end

  speed_profile :fast
  test "deleted? returns true for deleted files" do
    diff = FileDiff.new(
      file_path: "file.rb",
      change_type: :deleted
    )

    refute diff.added?
    refute diff.modified?
    assert diff.deleted?
  end

  # Serialization tests
  speed_profile :fast
  test "to_h returns hash representation" do
    diff_content = "--- a/file.rb\n+++ b/file.rb\n"
    diff = FileDiff.new(
      file_path: "app/models/user.rb",
      change_type: :modified,
      insertions: 5,
      deletions: 3,
      diff_content: diff_content,
      is_binary: false
    )

    hash = diff.to_h

    assert_equal "app/models/user.rb", hash[:file_path]
    assert_equal :modified, hash[:change_type]
    assert_equal 5, hash[:insertions]
    assert_equal 3, hash[:deletions]
    assert_equal diff_content, hash[:diff_content]
    refute hash[:is_binary]
  end

  speed_profile :fast
  test "from_h reconstructs FileDiff from hash" do
    hash = {
      file_path: "app/models/user.rb",
      change_type: :modified,
      insertions: 5,
      deletions: 3,
      diff_content: "--- a/file.rb\n",
      is_binary: false
    }

    diff = FileDiff.from_h(hash)

    assert_equal "app/models/user.rb", diff.file_path
    assert_equal :modified, diff.change_type
    assert_equal 5, diff.insertions
    assert_equal 3, diff.deletions
    refute diff.is_binary
  end

  speed_profile :fast
  test "from_h handles string keys" do
    hash = {
      "file_path" => "file.rb",
      "change_type" => "added",
      "insertions" => 10
    }

    diff = FileDiff.from_h(hash)

    assert_equal "file.rb", diff.file_path
    assert_equal :added, diff.change_type
    assert_equal 10, diff.insertions
  end

  speed_profile :fast
  test "from_h validates hash is required" do
    error = assert_raises(ArgumentError) do
      FileDiff.from_h(nil)
    end
    assert_match(/hash is required/, error.message)
  end

  speed_profile :fast
  test "from_h validates hash is a Hash" do
    error = assert_raises(ArgumentError) do
      FileDiff.from_h("not a hash")
    end
    assert_match(/hash must be a Hash/, error.message)
  end

  speed_profile :fast
  test "serialization round-trip preserves data" do
    original = FileDiff.new(
      file_path: "app/models/user.rb",
      change_type: :modified,
      insertions: 5,
      deletions: 3,
      diff_content: "--- a/file.rb\n+++ b/file.rb\n",
      is_binary: false
    )

    hash = original.to_h
    reconstructed = FileDiff.from_h(hash)

    assert_equal original.file_path, reconstructed.file_path
    assert_equal original.change_type, reconstructed.change_type
    assert_equal original.insertions, reconstructed.insertions
    assert_equal original.deletions, reconstructed.deletions
    assert_equal original.diff_content, reconstructed.diff_content
    assert_equal original.is_binary, reconstructed.is_binary
  end

  # Git diff parsing tests
  speed_profile :fast
  test "from_git_diff parses addition" do
    diff_output = <<~DIFF
      --- /dev/null
      +++ b/new_file.rb
      @@ -0,0 +1,3 @@
      +class NewFile
      +  def hello
      +  end
    DIFF

    diff = FileDiff.from_git_diff(diff_output)

    assert_equal "new_file.rb", diff.file_path
    assert_equal :added, diff.change_type
    assert_equal 3, diff.insertions
    assert_equal 0, diff.deletions
    refute diff.is_binary
  end

  speed_profile :fast
  test "from_git_diff parses deletion" do
    diff_output = <<~DIFF
      --- a/old_file.rb
      +++ /dev/null
      @@ -1,3 +0,0 @@
      -class OldFile
      -  def goodbye
      -  end
    DIFF

    diff = FileDiff.from_git_diff(diff_output)

    assert_equal "old_file.rb", diff.file_path
    assert_equal :deleted, diff.change_type
    assert_equal 0, diff.insertions
    assert_equal 3, diff.deletions
    refute diff.is_binary
  end

  speed_profile :fast
  test "from_git_diff parses modification" do
    diff_output = <<~DIFF
      --- a/modified_file.rb
      +++ b/modified_file.rb
      @@ -1,3 +1,4 @@
       class ModifiedFile
      +  def new_method
      +  end
         def old_method
         end
      -  def removed_method
      -  end
    DIFF

    diff = FileDiff.from_git_diff(diff_output)

    assert_equal "modified_file.rb", diff.file_path
    assert_equal :modified, diff.change_type
    assert_equal 2, diff.insertions
    assert_equal 2, diff.deletions
    refute diff.is_binary
  end

  speed_profile :fast
  test "from_git_diff detects binary files" do
    diff_output = "Binary files a/image.png and b/image.png differ"

    diff = FileDiff.from_git_diff(diff_output, file_path: "image.png")

    assert_equal "image.png", diff.file_path
    assert diff.is_binary
    assert_equal 0, diff.insertions
    assert_equal 0, diff.deletions
  end

  speed_profile :fast
  test "from_git_diff accepts explicit file_path" do
    diff_output = "+++ b/some/path/file.rb\n"

    diff = FileDiff.from_git_diff(diff_output, file_path: "explicit/path.rb")

    assert_equal "explicit/path.rb", diff.file_path
  end

  speed_profile :fast
  test "from_git_diff validates diff_output is required" do
    error = assert_raises(ArgumentError) do
      FileDiff.from_git_diff(nil)
    end
    assert_match(/diff_output is required/, error.message)
  end

  speed_profile :fast
  test "from_git_diff validates diff_output is a String" do
    error = assert_raises(ArgumentError) do
      FileDiff.from_git_diff(123)
    end
    assert_match(/diff_output must be a String/, error.message)
  end
end


