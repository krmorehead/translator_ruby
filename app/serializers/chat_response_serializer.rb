# frozen_string_literal: true

class ChatResponseSerializer
  def initialize(workflow)
    @workflow = workflow
  end

  def serialize
    if @workflow.complete?
      result = @workflow.result || {}
      {
        success: true,
        reply: result[:narrative].to_s,
        conversation: result[:conversation]&.to_h,
        error: nil
      }
    else
      {
        success: false,
        reply: fallback_reply,
        conversation: safe_conversation,
        error: @workflow.error
      }
    end
  end

  def serialize_json
    JSON.pretty_generate(serialize)
  end

  private

  def safe_conversation
    return unless @workflow.respond_to?(:conversation)

    @workflow.conversation&.to_h
  end

  def fallback_reply
    "Sorry, I couldn't complete that request."
  end
end


