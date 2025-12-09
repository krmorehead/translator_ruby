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

    llm_response = openai_client.chat(parameters: workflow.chat_parameters(user_prompt: user_message))
    tool_payload = parse_tool_payload(llm_response)
    tool_args = normalize_tool_arguments(tool_payload, user_message)
    tool_result = tool_call_service.execute(tool_name: tool_payload[:tool], arguments: tool_args)
    reply_text = render_reply_text(tool_result)

    convo << Message.new(
      source: "assistant",
      target: "user",
      message: reply_text,
      context: { tool: tool_payload[:tool], result: tool_result }
    )
    persist_conversation!(convo)

    render json: {
      success: true,
      reply: reply_text,
      conversation: convo.to_h,
      tool: tool_payload[:tool],
      arguments: tool_payload[:arguments],
      result: tool_result
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
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
      messages = []
      if File.exist?(CONVERSATION_PATH)
        data = JSON.parse(File.read(CONVERSATION_PATH), symbolize_names: true)
        messages = data[:messages] if data.is_a?(Hash)
      end
      Conversation.new(messages: messages)
    rescue JSON::ParserError
      Conversation.new
    end
  end

  def persist_conversation!(conv)
    FileUtils.mkdir_p(CONVERSATION_PATH.dirname)
    File.write(CONVERSATION_PATH, JSON.pretty_generate(conv.to_h))
  end

  def memory_store
    @memory_store ||= MemoryStore.new(path: MEMORY_PATH, sandbox_path: SANDBOX_ROOT)
  end

  def inventory_store
    @inventory_store ||= InventoryStore.new(path: INVENTORY_PATH, sandbox_path: SANDBOX_ROOT)
  end

  def workflow
    @workflow ||= DndChatWorkflow.new
  end

  def tool_call_service
    @tool_call_service ||= ToolCallService.new(sandbox_path: SANDBOX_ROOT)
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: ENV["LLM_URL"],
      request_timeout: 60
    )
  end

  def parse_tool_payload(response)
    message = response.dig("choices", 0, "message") || {}
    content = message["content"]

    if content.nil? && message["tool_calls"]
      call = message["tool_calls"].first
      name = call.dig("function", "name")
      raw_args = call.dig("function", "arguments")
      args = raw_args.is_a?(String) ? JSON.parse(raw_args) : (raw_args || {})
      return { tool: name, arguments: args }
    end

    raise "LLM response missing content" unless content

    parsed = JSON.parse(content)
    { tool: parsed["tool"], arguments: parsed["arguments"] || {} }
  end

  def normalize_tool_arguments(payload, user_message)
    tool = payload[:tool]
    args = (payload[:arguments] || {}).transform_keys(&:to_sym)

    case tool
    when MemoryTool::NAME
      args[:path] ||= MEMORY_PATH.to_s
      args[:append] = true if args[:append].nil?
      args[:operation] ||= MemoryTool::OP_UPDATE
      args[:section] ||= MemoryKinds::RECENT_CONVERSATION
      args[:content] ||= user_message
    when InventoryTool::NAME
      args[:path] ||= INVENTORY_PATH.to_s
    end

    args
  end

  def render_reply_text(tool_result)
    return tool_result[:result] if tool_result[:result].is_a?(String)

    JSON.pretty_generate(tool_result[:result])
  rescue
    tool_result[:result].to_s
  end

  def agent_version_value
    candidates = [CONVERSATION_PATH, MEMORY_PATH, INVENTORY_PATH].select { |p| File.exist?(p) }
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
