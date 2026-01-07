# frozen_string_literal: true

# Daedalus Agent - Plan generation and codebase exploration
# 
# Architecture:
#   AgentChatService → DaedalusAgent (worker) → Workflow → Prompt
#
# Based on Cline's Plan Agent architecture with codebase exploration tools
#
class DaedalusAgent
  attr_reader :session, :context
  
  # @param session [AgentSession] The agent session
  # @param context [Contexts::BaseContext] Context for the agent
  def initialize(session:, context:)
    validate_params!(session, context)
    
    @session = session
    @context = context
  end
  
  # Process a chat message using the chat workflow
  # @param content [String] User message
  # @return [Hash] Response with :content, :tool_calls, :file_changes
  def process_message(content:)
    workflow = build_chat_workflow
    workflow.execute(message: content)
  end
  
  private
  
  # Build the chat workflow with appropriate prompt
  # @return [Planning::DaedalusChatWorkflow] The workflow
  def build_chat_workflow
    Planning::DaedalusChatWorkflow.new(
      session: @session,
      context: @context
    )
  end
  
  def validate_params!(session, context)
    raise ArgumentError, "session must be an AgentSession" unless session.is_a?(AgentSession)
    raise ArgumentError, "context must be a Contexts::BaseContext" unless context.is_a?(Contexts::BaseContext)
    raise ArgumentError, "session must be for Daedalus agent" unless session.agent_type == AgentSession::AGENT_TYPE_DAEDALUS
  end
end

