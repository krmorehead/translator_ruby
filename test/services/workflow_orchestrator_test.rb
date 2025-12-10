# frozen_string_literal: true

require "test_helper"

class WorkflowOrchestratorTest < ActiveSupport::TestCase
  class ValidWorkflow
    attr_reader :setup_called, :execute_called, :prompt, :conversation, :sandbox_path

    def setup(prompt:, conversation:, sandbox_path:)
      @setup_called = true
      @prompt = prompt
      @conversation = conversation
      @sandbox_path = sandbox_path
      self
    end

    def execute
      @execute_called = true
    end

    def result; end
    def complete?; false; end
    def failed?; false; end
    def error; nil; end
  end

  class InvalidWorkflow
    def setup; end
  end

  test "raises when workflow missing required methods" do
    WorkflowOrchestrator # trigger autoload to define WorkflowError
    assert_raises(WorkflowError) { WorkflowOrchestrator.new(InvalidWorkflow.new) }
  end

  test "process calls setup then execute and returns workflow" do
    workflow = ValidWorkflow.new
    orchestrator = WorkflowOrchestrator.new(workflow)

    returned = orchestrator.process(prompt: "hi", conversation: :conv, sandbox_path: "/tmp/sandbox")

    assert_equal workflow, returned
    assert_equal true, workflow.setup_called
    assert_equal true, workflow.execute_called
    assert_equal "hi", workflow.prompt
    assert_equal :conv, workflow.conversation
    assert_equal "/tmp/sandbox", workflow.sandbox_path
  end
end

