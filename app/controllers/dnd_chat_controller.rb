# frozen_string_literal: true

class DndChatController < ApplicationController
  SANDBOX_ROOT = Rails.root.join("tmp", "dnd_chat_sandbox")
  INVENTORY_PATH = SANDBOX_ROOT.join("inventory.json")
  MEMORY_PATH = SANDBOX_ROOT.join("memory.json")
  CONVERSATION_PATH = SANDBOX_ROOT.join("conversation.json")

  before_action :ensure_sandbox!
  before_action :ensure_tools_loaded!

  def spa
    public_index = Rails.root.join("public", "index.html")
    built_index = Rails.root.join("frontend", "dist", "index.html")
    index_path = File.exist?(public_index) ? public_index : built_index

    unless File.exist?(index_path)
      return render plain: "Frontend not built. Run `cd frontend && npm run build`.", status: :service_unavailable
    end
    send_file index_path, type: "text/html", disposition: "inline"
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
    convo << Message.new(source: "user", target: "assistant", message: user_message)

    # DndAgentWorker handles all orchestration and persistence internally
    agent = DndAgentWorker.new(
      goal: user_message,
      path: SANDBOX_ROOT.to_s,
      memory_store: memory_store,
      conversation: convo
    )

    result = agent.execute

    render json: {
      success: result[:success],
      reply: result[:narrative],
      actions: result[:actions].map { |a| { action: a[:action], result: a[:result][:result] } },
      thoughts: result[:thoughts],
      conversation: result[:conversation].to_h
    }
  end

  def agent
    render json: {
      success: true,
      version: agent_version_value,
      state: {
        memories: memory_store.to_h,
        inventory: inventory_store.to_a,
        conversation: conversation.to_h[:messages]
      }
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def agent_version
    render json: {
      success: true,
      version: agent_version_value
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def ensure_sandbox!
    FileUtils.mkdir_p(SANDBOX_ROOT)
    reset_conversation_if_requested
    seed_story_if_needed
  end

  def ensure_tools_loaded!
    @tools_loaded ||= Dir[Rails.root.join("app/tools/*.rb")].sort.each { |path| require path }
  end

  def conversation
    @conversation ||= begin
      # Load conversation from memory store
      data = memory_store.get_section(MemoryKinds::RECENT_CONVERSATION)
      messages = data.is_a?(Hash) ? (data[:messages] || []) : []
      Conversation.new(messages: messages)
    end
  end

  def memory_store
    @memory_store ||= MemoryStore.new(path: MEMORY_PATH, sandbox_path: SANDBOX_ROOT)
  end

  def inventory_store
    @inventory_store ||= InventoryStore.new(path: INVENTORY_PATH, sandbox_path: SANDBOX_ROOT)
  end

  def agent_version_value
    candidates = [ CONVERSATION_PATH, MEMORY_PATH, INVENTORY_PATH ].select { |p| File.exist?(p) }
    return 0 if candidates.empty?

    candidates.map { |p| File.mtime(p).to_i }.max
  end

  def reset_conversation_if_requested
    reset_flag = ENV.fetch("DND_CHAT_RESET_CONVERSATION", Rails.env.development? ? "true" : "false")
    return unless reset_flag.to_s.downcase == "true"

    FileUtils.rm_f(CONVERSATION_PATH)
  end

  # Minimal defaults: scenario + main quest only
  def seed_story_if_needed
    return if File.exist?(MEMORY_PATH)

    store = MemoryStore.new(path: MEMORY_PATH, sandbox_path: SANDBOX_ROOT)
    # Leave sections empty; LLM will create scenario + main quest on first interaction per system prompt.
  end
end
