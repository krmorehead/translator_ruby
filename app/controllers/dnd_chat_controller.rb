# frozen_string_literal: true

class DndChatController < ApplicationController
  before_action :require_session_id, except: [:create_session, :messages_contract, :agent_contract, :agent_version_contract]
  before_action :load_session, except: [:create_session, :messages_contract, :agent_contract, :agent_version_contract]

  # POST /dnd/sessions - Create new D&D session
  def create_session
    session = DndSessionService.create_session

    render json: {
      success: true,
      session_id: session.session_id,
      message: "DnD session created"
    }, status: :created
  end

  def messages_contract
    render file: Rails.root.join("docs/api/contracts/dnd_chat_messages.yml"), content_type: "application/yaml"
  end

  def agent_contract
    render file: Rails.root.join("docs/api/contracts/dnd_chat_agent.yml"), content_type: "application/yaml"
  end

  def agent_version_contract
    render file: Rails.root.join("docs/api/contracts/dnd_chat_agent.yml"), content_type: "application/yaml"
  end

  def messages
    render json: @session.conversation.to_h
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def create_message
    user_message = params[:message].to_s
    return render json: { success: false, error: "message required" }, status: :bad_request if user_message.strip.empty?

    result = @session.process_message(user_message)

    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        conversation: result[:conversation]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :internal_server_error
    end
  rescue => e
    Rails.logger.error("DnD agent error: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def agent
    render json: {
      state: "ready",
      session_id: @session.session_id
    }
  end

  private

  def require_session_id
    @session_id = params[:session_id] || request.headers["X-Session-ID"]
    return if @session_id.present?

    render json: {
      success: false,
      error: "session_id required. Create a session first via POST /dnd/sessions"
    }, status: :bad_request
  end

  def load_session
    @session = DndSessionService.find_session!(@session_id)
  rescue ArgumentError => e
    render json: {
      success: false,
      error: e.message
    }, status: :not_found
  end
end
