# frozen_string_literal: true

class DndChatController < ApplicationController
  protect_from_forgery with: :exception

  SANDBOX_ROOT = Rails.root.join("tmp", "dnd_chat_sandbox")
  INVENTORY_PATH = SANDBOX_ROOT.join("inventory.json")
  MEMORY_PATH = SANDBOX_ROOT.join("memory.json")

  def index
    ensure_sandbox!
    render :index, locals: { initial_state: initial_state_json }
  end

  def create
    ensure_sandbox!
    message = params[:message].to_s
    if message.strip.empty?
      return render json: { success: false, error: "message required" }, status: :bad_request
    end

    workflow = DndChatWorkflow.new
    client = OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: ENV["LLM_URL"],
      request_timeout: 60
    )

    response = client.chat(parameters: workflow.chat_parameters(user_prompt: message))
    tool_payload = parse_tool_payload(response)

    tool_result = ToolCallService.new(sandbox_path: SANDBOX_ROOT).execute(
      tool_name: tool_payload[:tool],
      arguments: tool_payload[:arguments]
    )

    render json: {
      success: true,
      reply: tool_result[:result],
      tool: tool_payload[:tool],
      arguments: tool_payload[:arguments],
      result: tool_result
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def ensure_sandbox!
    FileUtils.mkdir_p(SANDBOX_ROOT)
  end

  def initial_state_json
    inv = InventoryStore.new(path: INVENTORY_PATH, sandbox_path: SANDBOX_ROOT)
    mem = MemoryStore.new(path: MEMORY_PATH, sandbox_path: SANDBOX_ROOT)
    {
      inventory: inv.to_a,
      memories: mem.to_h,
      inventory_path: INVENTORY_PATH.to_s,
      memory_path: MEMORY_PATH.to_s
    }.to_json
  end

  def parse_tool_payload(response)
    content = response.dig("choices", 0, "message", "content")
    raise "LLM response missing content" unless content
    parsed = JSON.parse(content)
    {
      tool: parsed["tool"],
      arguments: parsed["arguments"] || {}
    }
  end
end
