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
      
      unless AgentSession::VALID_AGENT_TYPES.include?(agent_type)
        return render json: {
          success: false,
          error: "Invalid agent_type: #{agent_type}. Valid types: #{AgentSession::VALID_AGENT_TYPES.join(', ')}"
        }, status: :unprocessable_entity
      end

      session = @service.create_session(agent_type: agent_type)
      
      render json: {
        success: true,
        session_id: session.session_id,
        agent_type: session.agent_type,
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

      unless [ChatMessage::ROLE_USER, ChatMessage::ROLE_AGENT, ChatMessage::ROLE_SYSTEM].include?(role)
        return render json: {
          success: false,
          error: "Invalid role: #{role}"
        }, status: :unprocessable_entity
      end

      # If user message, send to LLM and get response
      if role == ChatMessage::ROLE_USER
        # Store user message
        user_message = @service.add_message(
          session_id: session_id,
          role: role,
          content: content
        )

        # Get conversation history for context
        conversation = @service.get_conversation(session_id: session_id)
        messages = conversation.map { |msg| { role: msg.role, content: msg.content } }

        # Prepend persistent context as a system message if provided
        if persistent_context && !persistent_context.empty?
          Rails.logger.info("Including persistent context in LLM request")
          messages.unshift({
            role: "system",
            content: "PERSISTENT CONTEXT (always apply): #{persistent_context}"
          })
        end

        # Send to real LLM
        Rails.logger.info("Sending to LLM with #{messages.size} messages")
        llm_client = GenericLlmClient.client_for(:general_llm)
        llm_response = llm_client.chat(
          parameters: {
            model: GenericLlmClient::CAPABILITIES[:general_llm][:model_name],
            messages: messages,
            temperature: 0.7,
            max_tokens: 2000
          }
        )

        Rails.logger.info("LLM response class: #{llm_response.class}, has_content?: #{llm_response.has_content?}")
        
        # GenericLlmClient already returns an LlmResponse object
        agent_content = llm_response.content
        
        # Validate we got content
        unless agent_content && !agent_content.empty?
          Rails.logger.error("LLM returned empty content: #{llm_response.to_h.inspect}")
          Rails.logger.error("LLM response object: #{llm_response.inspect[0..500]}")
          return render json: {
            success: false,
            error: "LLM returned empty response"
          }, status: :internal_server_error
        end
        
        # Store agent response
        agent_message = @service.add_message(
          session_id: session_id,
          role: ChatMessage::ROLE_AGENT,
          content: agent_content,
          thoughts: nil, # TODO: Extract <think> tags
          metadata: { model: GenericLlmClient::CAPABILITIES[:general_llm][:model_name] }
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
  end
end
