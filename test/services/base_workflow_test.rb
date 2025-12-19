# frozen_string_literal: true

require "test_helper"

class BaseWorkflowTest < ActiveSupport::TestCase
  class SampleWorkflow < BaseWorkflow
    def execute
      trigger(:start) # Move to running state
      mark_complete(ok: true, prompt: prompt)
    end
  end

  class FailingWorkflow < BaseWorkflow
    def execute
      trigger(:start) # Move to running state first
      mark_failed("boom")
    end
  end

  test "execute is abstract on base class" do
    assert_raises(NotImplementedError) { BaseWorkflow.new.execute }
  end

  test "setup stores prompt and conversation" do
    workflow = SampleWorkflow.new
    conversation = Object.new
    result = workflow.setup(prompt: "hi", conversation: conversation)

    assert_equal workflow, result
    assert_equal "hi", workflow.prompt
    assert_equal conversation, workflow.conversation
  end

  test "workflow_name returns underscored class name" do
    assert_equal "sample_workflow", SampleWorkflow.workflow_name
  end

  test "marks complete with result" do
    workflow = SampleWorkflow.new
    workflow.setup(prompt: "hi", conversation: nil)
    workflow.execute

    assert_predicate workflow, :complete?
    refute_predicate workflow, :failed?
    assert_equal({ ok: true, prompt: "hi" }, workflow.result)
    assert_nil workflow.error
  end

  test "marks failed with error" do
    workflow = FailingWorkflow.new
    workflow.setup(prompt: "oops", conversation: nil)
    workflow.execute

    assert_predicate workflow, :failed?
    refute_predicate workflow, :complete?
    assert_equal "boom", workflow.error
    assert_nil workflow.result
  end
end
