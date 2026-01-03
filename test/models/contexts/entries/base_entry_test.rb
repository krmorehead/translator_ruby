# frozen_string_literal: true

require "test_helper"

module Contexts
  module Entries
    class BaseEntryTest < ActiveSupport::TestCase
      speed_profile :fast
      test "creates a valid base entry" do
        entry = BaseEntry.new(
          content: "Test content",
          topics: ["test", "example"],
          source: "test_source",
          metadata: { key: "value" }
        )

        assert_equal "Test content", entry.content
        assert_equal ["test", "example"], entry.topics
        assert_equal "test_source", entry.source
        assert_equal({ key: "value" }, entry.metadata)
        assert_not_nil entry.id
        assert_not_nil entry.timestamp
      end

      speed_profile :fast
      test "normalizes topics to lowercase and strips whitespace" do
        entry = BaseEntry.new(
          content: "Test",
          topics: ["  TEST  ", "Example", "UPPERCASE"],
          source: "test"
        )

        assert_equal ["test", "example", "uppercase"], entry.topics
      end

      speed_profile :fast
      test "removes empty topics" do
        entry = BaseEntry.new(
          content: "Test",
          topics: ["valid", "", "  ", "another"],
          source: "test"
        )

        assert_equal ["valid", "another"], entry.topics
      end

      speed_profile :fast
      test "removes duplicate topics" do
        entry = BaseEntry.new(
          content: "Test",
          topics: ["test", "example", "test", "Example"],
          source: "test"
        )

        assert_equal ["test", "example"], entry.topics
      end

      speed_profile :fast
      test "validates content is a String" do
        error = assert_raises(ArgumentError) do
          BaseEntry.new(content: 123, topics: [], source: "test")
        end
        assert_match(/content must be a String/, error.message)
      end

      speed_profile :fast
      test "validates topics is an Array" do
        error = assert_raises(ArgumentError) do
          BaseEntry.new(content: "Test", topics: "not-array", source: "test")
        end
        assert_match(/topics must be an Array/, error.message)
      end

      speed_profile :fast
      test "validates source is a String" do
        error = assert_raises(ArgumentError) do
          BaseEntry.new(content: "Test", topics: [], source: 123)
        end
        assert_match(/source must be a String/, error.message)
      end

      speed_profile :fast
      test "validates metadata is a Hash" do
        error = assert_raises(TypeError) do
          BaseEntry.new(content: "Test", topics: [], source: "test", metadata: "not-hash")
        end
        assert_match(/metadata must be a Hash/, error.message)
      end

      speed_profile :fast
      test "to_h serializes entry properly" do
        entry = BaseEntry.new(
          content: "Test content",
          topics: ["test"],
          source: "source",
          metadata: { key: "value" }
        )

        hash = entry.to_h

        assert_equal entry.id, hash[:id]
        assert_equal "Test content", hash[:content]
        assert_equal ["test"], hash[:topics]
        assert_equal "source", hash[:source]
        assert_equal entry.timestamp, hash[:timestamp]
        assert_equal({ key: "value" }, hash[:metadata])
      end

      speed_profile :fast
      test "from_h reconstructs entry from hash" do
        original = BaseEntry.new(
          content: "Original content",
          topics: ["test", "example"],
          source: "test_source",
          metadata: { test: true }
        )

        hash = original.to_h
        reconstructed = BaseEntry.from_h(hash)

        assert_equal original.id, reconstructed.id
        assert_equal original.content, reconstructed.content
        assert_equal original.topics, reconstructed.topics
        assert_equal original.source, reconstructed.source
        assert_equal original.timestamp, reconstructed.timestamp
        assert_equal original.metadata, reconstructed.metadata
      end

      speed_profile :fast
      test "from_h validates hash structure" do
        error = assert_raises(TypeError) do
          BaseEntry.from_h("not a hash")
        end
        assert_match(/Expected Hash/, error.message)

        error = assert_raises(ArgumentError) do
          BaseEntry.from_h({ "id" => "123" })
        end
        assert_match(/Hash keys must be symbols/, error.message)

        error = assert_raises(ArgumentError) do
          BaseEntry.from_h({ id: "123" })
        end
        assert_match(/Missing required keys/, error.message)
      end
    end
  end
end


