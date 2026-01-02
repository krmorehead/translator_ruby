# frozen_string_literal: true

class DndChatController < ApplicationController
  before_action :ensure_tools_loaded!
  before_action :require_session_id, except: [:create_session, :spa]
  before_action :load_session, except: [:create_session, :spa]

  def spa
    public_index = Rails.root.join("public", "index.html")
    built_index = Rails.root.join("frontend", "dist", "index.html")
    index_path = File.exist?(public_index) ? public_index : built_index

    unless File.exist?(index_path)
      return render plain: "Frontend not built. Run `cd frontend && npm run build`.", status: :service_unavailable
    end
    send_file index_path, type: "text/html", disposition: "inline"
  end

  # POST /dnd/sessions - Create new DnD session
  def create_session
    session_id = SecureRandom.uuid
    session_path = File.join(sessions_root, session_id)
    FileUtils.mkdir_p(session_path)

    worker = DndAgentWorker.new(
      goal: "Facilitate D&D game session",
      path: session_path
    )

    render json: {
      success: true,
      session_id: session_id,
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
    render json: conversation.to_h
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def create_message
    user_message = params[:message].to_s
    return render json: { success: false, error: "message required" }, status: :bad_request if user_message.strip.empty?

    convo = conversation
    convo.add_message(role: :user, content: user_message)

    Rails.logger.info("Running DnD agent for message: #{user_message}")
    result = @dnd_worker.execute

    if result[:state] == :complete
      assistant_response = result[:narrative] || "The story continues..."
      convo.add_message(role: :assistant, content: assistant_response)

      # Save conversation to memory
      memory_store.set_section(
        MemoryKinds::RECENT_CONVERSATION,
        { messages: convo.messages }
      )

      render json: {
        success: true,
        message: assistant_response,
        conversation: convo.to_h
      }
    else
      render json: {
        success: false,
        error: "Agent did not complete successfully. State: #{result[:state]}"
      }, status: :internal_server_error
    end
  rescue => e
    Rails.logger.error("DnD agent error: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def agent
    render json: {
      state: "ready",
      version: agent_version_value,
      session_id: @session_id
    }
  end

  def agent_version
    render json: { version: agent_version_value }
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
    session_path = File.join(sessions_root, @session_id)
    
    unless File.directory?(session_path)
      return render json: {
        success: false,
        error: "Session not found: #{@session_id}"
      }, status: :not_found
    end

    @dnd_worker = DndAgentWorker.new(
      goal: "Facilitate D&D game session",
      path: session_path
    )
    @memory_store = @dnd_worker.memory_store
  end

  def sessions_root
    @sessions_root ||= Rails.root.join("data", "dnd_sessions").to_s.tap do |path|
      FileUtils.mkdir_p(path)
    end
  end

  def data_path
    File.join(sessions_root, @session_id)
  end

  def memory_path
    File.join(data_path, "memory.json")
  end

  def inventory_path
    File.join(data_path, "inventory.json")
  end

  def conversation_path
    File.join(data_path, "conversation.json")
  end

  def ensure_tools_loaded!
    @tools_loaded ||= Dir[Rails.root.join("app/tools/*.rb")].sort.each { |path| require path }
  end

  def conversation
    @conversation ||= begin
      # Load conversation from memory store
      data = @memory_store.get_section(MemoryKinds::RECENT_CONVERSATION)
      messages = data.is_a?(Hash) ? (data[:messages] || []) : []
      Conversation.new(messages: messages)
    end
  end

  def memory_store
    @memory_store
  end

  def inventory_store
    @inventory_store ||= InventoryStore.new(path: inventory_path)
  end

  def agent_version_value
    candidates = [conversation_path, memory_path, inventory_path].select { |p| File.exist?(p) }
    return 0 if candidates.empty?

    candidates.map { |p| File.mtime(p).to_i }.max
  end
end
