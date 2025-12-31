# frozen_string_literal: true

require "test_helper"

module Planning
  class FileReferenceTest < ActiveSupport::TestCase
    test "initialization with existing file parameters" do
      ref = FileReference.new(
        path: "app/models/user.rb",
        description: "User model with authentication",
        relevance: "Contains auth logic"
      )

      assert_equal "app/models/user.rb", ref.path
      assert_equal "User model with authentication", ref.description
      assert_equal "Contains auth logic", ref.relevance
      assert_nil ref.created_in_step
    end

    test "initialization with planned file parameters" do
      ref = FileReference.new(
        path: "app/services/payment_service.rb",
        description: "Handles payment processing",
        created_in_step: "2.3"
      )

      assert_equal "app/services/payment_service.rb", ref.path
      assert_equal "Handles payment processing", ref.description
      assert_nil ref.relevance
      assert_equal "2.3", ref.created_in_step
    end

    test "validates path must be a String" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: 123,
          description: "Test",
          relevance: "Test"
        )
      end
      assert_match(/path must be a String/, error.message)
    end

    test "validates path cannot be empty" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: "  ",
          description: "Test",
          relevance: "Test"
        )
      end
      assert_match(/path cannot be empty/, error.message)
    end

    test "validates description must be a String" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: "app/models/user.rb",
          description: nil,
          relevance: "Test"
        )
      end
      assert_match(/description must be a String/, error.message)
    end

    test "validates description cannot be empty" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: "app/models/user.rb",
          description: "  ",
          relevance: "Test"
        )
      end
      assert_match(/description cannot be empty/, error.message)
    end

    test "validates relevance must be String or nil" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: "app/models/user.rb",
          description: "Test",
          relevance: 123
        )
      end
      assert_match(/relevance must be a String or nil/, error.message)
    end

    test "validates created_in_step must be String or nil" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: "app/models/user.rb",
          description: "Test",
          created_in_step: 123
        )
      end
      assert_match(/created_in_step must be a String or nil/, error.message)
    end

    test "validates either relevance or created_in_step must be provided" do
      error = assert_raises(ArgumentError) do
        FileReference.new(
          path: "app/models/user.rb",
          description: "Test"
        )
      end
      assert_match(/Either relevance.*or created_in_step.*must be provided/, error.message)
    end

    test "to_h produces correct hash structure for existing file" do
      ref = FileReference.new(
        path: "app/models/user.rb",
        description: "User model",
        relevance: "Auth logic"
      )

      hash = ref.to_h

      assert_equal "app/models/user.rb", hash[:path]
      assert_equal "User model", hash[:description]
      assert_equal "Auth logic", hash[:relevance]
      assert_nil hash[:created_in_step]
    end

    test "to_h produces correct hash structure for planned file" do
      ref = FileReference.new(
        path: "app/services/payment_service.rb",
        description: "Payment processing",
        created_in_step: "2.3"
      )

      hash = ref.to_h

      assert_equal "app/services/payment_service.rb", hash[:path]
      assert_equal "Payment processing", hash[:description]
      assert_equal "2.3", hash[:created_in_step]
      assert_nil hash[:relevance]
    end

    test "from_h reconstructs object correctly with symbol keys" do
      original = FileReference.new(
        path: "app/models/user.rb",
        description: "User model",
        relevance: "Auth logic"
      )

      hash = original.to_h
      reconstructed = FileReference.from_h(hash)

      assert_equal original.path, reconstructed.path
      assert_equal original.description, reconstructed.description
      assert_equal original.relevance, reconstructed.relevance
      assert_equal original.created_in_step, reconstructed.created_in_step
    end

    test "from_h reconstructs object correctly with string keys" do
      hash = {
        "path" => "app/models/user.rb",
        "description" => "User model",
        "relevance" => "Auth logic"
      }

      reconstructed = FileReference.from_h(hash)

      assert_equal "app/models/user.rb", reconstructed.path
      assert_equal "User model", reconstructed.description
      assert_equal "Auth logic", reconstructed.relevance
    end

    test "from_h validates input must be Hash" do
      error = assert_raises(ArgumentError) do
        FileReference.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    test "existing? returns true for existing files" do
      ref = FileReference.new(
        path: "app/models/user.rb",
        description: "User model",
        relevance: "Auth logic"
      )

      assert ref.existing?
      refute ref.planned?
    end

    test "planned? returns true for planned files" do
      ref = FileReference.new(
        path: "app/services/payment_service.rb",
        description: "Payment processing",
        created_in_step: "2.3"
      )

      assert ref.planned?
      refute ref.existing?
    end

    test "normalizes path by removing leading ./" do
      ref = FileReference.new(
        path: "./app/models/user.rb",
        description: "User model",
        relevance: "Auth logic"
      )

      assert_equal "app/models/user.rb", ref.path
    end

    test "normalizes path by trimming whitespace" do
      ref = FileReference.new(
        path: "  app/models/user.rb  ",
        description: "User model",
        relevance: "Auth logic"
      )

      assert_equal "app/models/user.rb", ref.path
    end

    test "serialization round-trip preserves data" do
      original = FileReference.new(
        path: "app/models/user.rb",
        description: "User model with authentication",
        relevance: "Contains auth logic"
      )

      hash = original.to_h
      reconstructed = FileReference.from_h(hash)

      assert_equal original.path, reconstructed.path
      assert_equal original.description, reconstructed.description
      assert_equal original.relevance, reconstructed.relevance
      assert_equal original.existing?, reconstructed.existing?
      assert_equal original.planned?, reconstructed.planned?
    end
  end
end

