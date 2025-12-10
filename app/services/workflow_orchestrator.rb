# frozen_string_literal: true

class WorkflowError < StandardError; end

class WorkflowOrchestrator
  REQUIRED_METHODS = %i[setup execute result complete? failed? error].freeze

  def initialize(workflow)
    @workflow = workflow
    validate_workflow!
  end

  def process(prompt:, conversation:, sandbox_path:)
    @workflow.setup(prompt: prompt, conversation: conversation, sandbox_path: sandbox_path)
    @workflow.execute
    @workflow
  end

  private

  def validate_workflow!
    missing = REQUIRED_METHODS.reject { |method| @workflow.respond_to?(method) }
    raise WorkflowError, "Workflow missing required methods: #{missing.join(', ')}" if missing.any?
  end
end

