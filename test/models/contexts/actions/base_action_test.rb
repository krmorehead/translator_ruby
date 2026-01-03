# frozen_string_literal: true

require "test_helper"

module Contexts
  module Actions
    class BaseActionTest < ActiveSupport::TestCase
      speed_profile :fast
      test "creates a valid base action" do
        action = BaseAction.new(
          name: :search_files,
          arguments: { pattern: "test" },
          result: { success: true, count: 5 },
          iteration: 1,
          cached: false
        )

        assert_equal :search_files, action.name
        assert_equal({ pattern: "test" }, action.arguments)
        assert action.success
        assert_equal "Found 5 items", action.result_summary
        assert_equal 1, action.iteration
        assert_not action.cached
        assert_not_nil action.id
        assert_not_nil action.timestamp
      end

      speed_profile :fast
      test "successful? returns correct value" do
        success_action = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: true },
          iteration: 1
        )
        assert success_action.successful?

        failed_action = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: false },
          iteration: 1
        )
        assert_not failed_action.successful?
      end

      speed_profile :fast
      test "failed? returns opposite of successful?" do
        action = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: true },
          iteration: 1
        )
        assert_not action.failed?

        failed = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: false },
          iteration: 1
        )
        assert failed.failed?
      end

      speed_profile :fast
      test "extracts result summary from error" do
        action = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: false, error: "Not found" },
          iteration: 1
        )
        assert_equal "Not found", action.result_summary
      end

      speed_profile :fast
      test "extracts result summary from summary" do
        action = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: true, summary: "All done" },
          iteration: 1
        )
        assert_equal "All done", action.result_summary
      end

      speed_profile :fast
      test "extracts result summary from count" do
        action = BaseAction.new(
          name: :test,
          arguments: {},
          result: { success: true, count: 10 },
          iteration: 1
        )
        assert_equal "Found 10 items", action.result_summary
      end

      speed_profile :fast
      test "to_h serializes action properly" do
        action = BaseAction.new(
          name: :test_action,
          arguments: { key: "value" },
          result: { success: true, summary: "Done" },
          iteration: 2,
          cached: true
        )

        hash = action.to_h

        assert_equal action.id, hash[:id]
        assert_equal :test_action, hash[:name]
        assert_equal({ key: "value" }, hash[:arguments])
        assert hash[:success]
        assert_equal "Done", hash[:result_summary]
        assert_equal 2, hash[:iteration]
        assert hash[:cached]
        assert_equal action.timestamp, hash[:timestamp]
      end

      speed_profile :fast
      test "from_h reconstructs action from hash" do
        original = BaseAction.new(
          name: :original,
          arguments: { test: true },
          result: { success: true, summary: "Complete" },
          iteration: 3,
          cached: true
        )

        hash = original.to_h
        reconstructed = BaseAction.from_h(hash)

        assert_equal original.id, reconstructed.id
        assert_equal original.name, reconstructed.name
        assert_equal original.arguments, reconstructed.arguments
        assert_equal original.success, reconstructed.success
        assert_equal original.result_summary, reconstructed.result_summary
        assert_equal original.iteration, reconstructed.iteration
        assert_equal original.cached, reconstructed.cached
      end

      speed_profile :fast
      test "validates parameters" do
        error = assert_raises(ArgumentError) do
          BaseAction.new(name: 123, arguments: {}, result: { success: true }, iteration: 1)
        end
        assert_match(/name must be a Symbol or String/, error.message)

        error = assert_raises(ArgumentError) do
          BaseAction.new(name: :test, arguments: "not-hash", result: { success: true }, iteration: 1)
        end
        assert_match(/arguments must be a Hash/, error.message)

        error = assert_raises(TypeError) do
          BaseAction.new(name: :test, arguments: {}, result: "not-hash", iteration: 1)
        end
        assert_match(/result must be a Hash/, error.message)
      end
    end
  end
end








