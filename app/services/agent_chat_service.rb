# frozen_string_literal: true

# Service for routing agent chat messages to appropriate WORKERS.
# Workers own their workflows, which own their prompts.
#
# Architecture:
#   AgentChatService → Worker (DaedalusWorker/SisyphusWorker) → Workflow → Prompt
#
# @example Process Daedalus message
#   service = AgentChatService.new(session: session, context: context)
#   result = service.process_message(content: "What services exist?")
#   # => { content: "...", tool_calls: [...], file_changes: [...] }
#
class AgentChatService
  attr_reader :session, :context
  
  # @param session [AgentSession] The agent session
  # @param context [Contexts::BaseContext] Context with persistent context
  def initialize(session:, context:)
    validate_params!(session, context)
    
    @session = session
    @context = context
  end
  
  # Process a user message and return agent response
  # Delegates to the appropriate WORKER
  # @param content [String] User message content
  # @return [Hash] Response with :content, :tool_calls, :file_changes
  def process_message(content:)
    # Get the appropriate worker for this agent type
    worker = build_worker
    
    # Extract conversation history
    conversation_history = extract_conversation_history
    
    # Worker handles message processing with its workflows and prompts
    result = worker.process_message(
      content: content,
      conversation_history: conversation_history
    )
    
    # Return standardized response
    {
      content: result[:content],
      tool_calls: result[:tool_calls] || [],
      file_changes: result[:file_changes] || []
    }
  end
  
  private
  
  # Build the appropriate worker for the agent type
  # @return [BaseWorker] Instantiated worker (DaedalusWorker or SisyphusWorker)
  def build_worker
    case @session.agent_type
    when AgentSession::AGENT_TYPE_DAEDALUS
      DaedalusWorker.new(
        goal: "Explore and answer questions about the codebase",
        path: @session.project_path || Dir.pwd,
        context: @context
      )
    when AgentSession::AGENT_TYPE_SISYPHUS
      SisyphusWorker.new(
        path: @session.project_path || Dir.pwd,
        context: @context
      )
    else
      raise ArgumentError, "Unknown agent type: #{@session.agent_type}"
    end
  end
  
  # Extract conversation history from context
  # @return [Array<Hash>] Conversation messages
  def extract_conversation_history
    # For now, return empty array
    # TODO!!!
    # In future, extract from context or session
    []
  end
  
  def validate_params!(session, context)
    raise ArgumentError, "session must be an AgentSession" unless session.is_a?(AgentSession)
    raise ArgumentError, "context must be a Contexts::BaseContext" unless context.is_a?(Contexts::BaseContext)
  end
end

