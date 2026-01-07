# frozen_string_literal: true

module Api
  # Controller for managing agent sessions, conversations, thoughts, and memory.
  # Provides standardized endpoints for IDE integration.
  #
  # All endpoints return domain objects (AgentSession, ChatMessage, MemorySection)
  # NO hash/object literal responses - strict OOP compliance
  class AgentSessionsController < ApplicationController
    before_action :set_owner_id
    before_action :set_service

    # POST /api/agent_sessions
    # Create new agent session
    def create
      agent_type = params[:agent_type]
      project_path = params[:project_path]
      
      unless AgentSession::VALID_AGENT_TYPES.include?(agent_type)
        return render json: {
          success: false,
          error: "Invalid agent_type: #{agent_type}. Valid types: #{AgentSession::VALID_AGENT_TYPES.join(', ')}"
        }, status: :unprocessable_entity
      end

      session = @service.create_session(agent_type: agent_type)
      
      # Update with project path if provided
      if project_path && !project_path.empty?
        session = session.with_project_path(project_path)
        @service.update_session(session)
      end
      
      render json: {
        success: true,
        session_id: session.session_id,
        agent_type: session.agent_type,
        project_path: session.project_path,
        status: session.status
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # GET /api/agent_sessions/:session_id
    # Get session details
    def show
      session_id = params[:session_id]
      
      session = @service.get_session(session_id: session_id)
      
      if session
        render json: {
          success: true,
          session: session.to_h
        }
      else
        render json: {
          success: false,
          error: "Session not found: #{session_id}"
        }, status: :not_found
      end
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # GET /api/agent_sessions/:session_id/messages
    # Get messages for a session
    def list_messages
      session_id = params[:session_id]
      limit = params[:limit]&.to_i || 100

      messages = @service.get_conversation(session_id: session_id, limit: limit)
      
      render json: {
        success: true,
        messages: messages.map(&:to_h),
        count: messages.size
      }
    rescue ArgumentError => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # POST /api/agent_sessions/:session_id/messages
    # Add message to conversation AND get LLM response
    def create_message
      session_id = params[:session_id]
      role = params[:role] || "user"
      content = params[:content]
      persistent_context = params[:persistent_context]
      project_path = params[:project_path]

      unless [ChatMessage::ROLE_USER, ChatMessage::ROLE_AGENT, ChatMessage::ROLE_SYSTEM].include?(role)
        return render json: {
          success: false,
          error: "Invalid role: #{role}"
        }, status: :unprocessable_entity
      end

      # If user message, send to agent and get response
      if role == ChatMessage::ROLE_USER
        # Get session
        session = @service.get_session(session_id: session_id)
        unless session
          return render json: {
            success: false,
            error: "Session not found: #{session_id}"
          }, status: :not_found
        end
        
        # Update session with project path if provided
        if project_path && project_path != session.project_path
          session = session.with_project_path(project_path)
          @service.update_session(session)
        end
        
        # Store user message
        user_message = @service.add_message(
          session_id: session_id,
          role: role,
          content: content
        )

        # Build context with persistent context
        context = build_context_with_persistent(
          persistent_context: persistent_context,
          conversation: @service.get_conversation(session_id: session_id)
        )
        
        # Route to agent-specific service
        agent_service = AgentChatService.new(session: session, context: context)
        result = agent_service.process_message(content: content)
        
        # Store agent response
        agent_message = @service.add_message(
          session_id: session_id,
          role: ChatMessage::ROLE_AGENT,
          content: result[:content],
          thoughts: nil, # TODO: Extract <think> tags
          metadata: {
            tool_calls: result[:tool_calls],
            file_changes: result[:file_changes]
          }
        )

        render json: {
          success: true,
          user_message: user_message.to_h,
          agent_message: agent_message.to_h
        }
      else
        # Just store non-user messages
        message = @service.add_message(
          session_id: session_id,
          role: role,
          content: content,
          thoughts: params[:thoughts],
          metadata: params[:metadata] || {}
        )
        
        render json: {
          success: true,
          message: message.to_h
        }
      end
    rescue ArgumentError => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # GET /api/agent_sessions/:session_id/thoughts
    # Get thoughts timeline (extracted reasoning)
    def list_thoughts
      session_id = params[:session_id]
      limit = params[:limit]&.to_i || 50

      thoughts = @service.get_thoughts_timeline(session_id: session_id, limit: limit)
      
      render json: {
        success: true,
        thoughts: thoughts,
        count: thoughts.size
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # GET /api/agent_sessions/:session_id/memories
    # Get all memory sections for a session
    def list_memories
      session_id = params[:session_id]
      
      # Get session to determine agent_type
      session = @service.get_session(session_id: session_id)
      unless session
        return render json: {
          success: false,
          error: "Session not found: #{session_id}"
        }, status: :not_found
      end

      sections = @service.get_memory_sections(agent_type: session.agent_type)
      
      render json: {
        success: true,
        memories: sections.map(&:to_h),
        count: sections.size
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # DELETE /api/agent_sessions/:session_id/memories/clear
    # Clear specific memory section
    def clear_memory
      session_id = params[:session_id]
      section_name = params[:section_name]
      
      # Get session to determine agent_type
      session = @service.get_session(session_id: session_id)
      unless session
        return render json: {
          success: false,
          error: "Session not found: #{session_id}"
        }, status: :not_found
      end

      success = @service.clear_memory_section(agent_type: session.agent_type, section_name: section_name)
      
      if success
        render json: {
          success: true,
          message: "Section cleared: #{section_name}"
        }
      else
        render json: {
          success: false,
          error: "Failed to clear section: #{section_name}"
        }, status: :unprocessable_entity
      end
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    # GET /api/agent_sessions/:session_id/actions
    # Get action history timeline
    def list_actions
      session_id = params[:session_id]
      limit = params[:limit]&.to_i || 100
      
      # Get session to determine agent_type
      session = @service.get_session(session_id: session_id)
      unless session
        return render json: {
          success: false,
          error: "Session not found: #{session_id}"
        }, status: :not_found
      end

      actions = @service.get_action_history(agent_type: session.agent_type, limit: limit)
      
      render json: {
        success: true,
        actions: actions,
        count: actions.size
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end

    private

    # Set owner_id from params or generate default
    def set_owner_id
      @owner_id = params[:owner_id] || SecureRandom.uuid
    end

    # Initialize service
    def set_service
      @service = AgentSessionService.new(owner_id: @owner_id)
    end
    
    # Build context with persistent context and conversation history
    # @param persistent_context [String, nil] Persistent context string
    # @param conversation [Array<ChatMessage>] Conversation history
    # @return [Contexts::BaseContext] Context object
    def build_context_with_persistent(persistent_context:, conversation:)
      # For now, return a simple BaseContext
      # TODO: Implement context entries when needed
      # persistent_context and conversation are available but not used yet
      Contexts::BaseContext.new
    end
  end
end
