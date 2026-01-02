# frozen_string_literal: true

require "test_helper"

module Graph
  class ContextTypeRegistryTest < ActiveSupport::TestCase
    speed_profile :fast
    test "has registered types" do
      types = ContextTypeRegistry.registered_types

      assert types.is_a?(Array)
      assert types.size > 0
    end

    speed_profile :fast
    test "includes workflow memory types" do
      types = ContextTypeRegistry.registered_types

      assert_includes types, :decision
      assert_includes types, :state_transition
      assert_includes types, :workflow_context
      assert_includes types, :error
      assert_includes types, :output
    end

    speed_profile :fast
    test "includes research memory types" do
      types = ContextTypeRegistry.registered_types

      assert_includes types, :research_goal
      assert_includes types, :sub_questions
      assert_includes types, :context_chain
      assert_includes types, :findings
    end

    speed_profile :fast
    test "returns sections for context type" do
      sections = ContextTypeRegistry.sections_for(:decision)

      assert_equal [:decisions], sections
    end

    speed_profile :fast
    test "returns empty array for unknown context type" do
      sections = ContextTypeRegistry.sections_for(:unknown_type)

      assert_equal [], sections
    end

    speed_profile :fast
    test "checks if context type is registered" do
      assert ContextTypeRegistry.registered?(:decision)
      assert ContextTypeRegistry.registered?(:research_goal)
      refute ContextTypeRegistry.registered?(:unknown_type)
    end

    speed_profile :fast
    test "handles string context types" do
      sections = ContextTypeRegistry.sections_for("decision")

      assert_equal [:decisions], sections
    end
  end
end
