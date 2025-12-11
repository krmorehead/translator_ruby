# frozen_string_literal: true

require "tmpdir"
require_relative "base_workflow"
require_relative "../prompts/action_detection_prompt"
require_relative "../prompts/outcome_prompt"
require_relative "../prompts/narrative_prompt"
require_relative "../models/action_record"
require_relative "../models/workflow_state"
require_relative "../models/memory_store"
require_relative "../models/memory_kinds"
require_relative "../models/memories/actions_memory"
require_relative "../tools/current_context_tool"
require_relative "../tools/context_compression_tool"
require_relative "../services/tool_call_service"
require_relative "../models/conversation"
require_relative "../models/message"

# Workflow orchestrating DnD chat: detect actions, run tools, resolve consequences, narrate.
class DndChatWorkflow < BaseWorkflow
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a DnD assistant with access to tools (memory, inventory, dice, skill checks, etc.).
    Respond by selecting appropriate tools and narrating outcomes in a story-focused way.
  PROMPT

  def self.workflow_name
    "dnd_chat"
  end

  def initialize(tool_call_service: nil, memory_store_class: MemoryStore)
    super()
    @tool_call_service = tool_call_service
    @memory_store_class = memory_store_class
  end

  # Temporary compatibility for controller/tests until controller is refactored to orchestrator path.
  # Builds OpenAI chat parameters for tool selection.
  def chat_parameters(user_prompt:, model: ENV["LLM_MODEL"] || "qwen30b", extra_system_prompt: nil, tools: ToolCallService.available_dnd_tools)
    tool_names = tools.map { |t| t[:function][:name] }
    {
      model: model,
      messages: [
        { role: "system", content: system_prompt(extra_system_prompt) },
        { role: "user", content: user_prompt }
      ],
      tools: tools,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "tool_call",
          strict: true,
          schema: {
            type: "object",
            properties: {
              tool: { type: "string", enum: tool_names },
              arguments: { type: "object", additionalProperties: true }
            },
            required: %w[tool arguments],
            additionalProperties: false
          }
        }
      }
    }
  end

  # Orchestrates the full workflow; marks complete or failed accordingly.
  def execute
    state = WorkflowState.new(status: STATUSES[:running], prompt: prompt)

    memory_store = build_memory_store
    tools = available_dnd_tools

    detected_actions = detect_actions(tools: tools, memory_store: memory_store)
    action_records = detected_actions.map do |action|
      ActionRecord.new(
        prompt_reference: action["prompt_reference"],
        tool_name: action["tool_name"],
        arguments: symbolize_keys(action["arguments"] || {})
      )
    end

    completed_actions = process_actions(action_records, memory_store)

    narrative = generate_narrative(completed_actions, memory_store)
    assistant_message = Message.new(source: "assistant", target: "user", message: narrative)
    conversation << assistant_message if conversation

    result_hash = {
      narrative: narrative,
      actions: completed_actions.map(&:to_h),
      conversation: conversation
    }

    mark_complete(result_hash)
    state = state.with(status: STATUSES[:complete], data: result_hash)
    state
  rescue => e
    mark_failed(e.message)
    state = state&.with(status: STATUSES[:failed], error: e.message) || WorkflowState.new(status: STATUSES[:failed], error: e.message)
    state
  end

  private

  def build_memory_store
    path = File.join(sandbox_path || Dir.mktmpdir, "memory.json")
    @memory_store_class.new(path: path, sandbox_path: sandbox_path)
  end

  def available_dnd_tools
    ToolCallService.available_dnd_tools
  end

  def detect_actions(tools:, memory_store:)
    prompt = ActionDetectionPrompt.new(tools: tools)
    context = {
      scene: memory_store.get_section(MemoryKinds::CURRENT_SCENE),
      memory: memory_store.to_h,
      recent_conversation: memory_store.get_section(MemoryKinds::RECENT_CONVERSATION)
    }
    prompt.execute(prompt: self.prompt, context: context)
  end

  def process_actions(action_records, memory_store)
    service = @tool_call_service || ToolCallService.new(sandbox_path: sandbox_path)
    completed = []

    action_records.each do |record|
      result = service.execute(tool_name: record.tool_name, arguments: record.arguments)
      record = if result[:success]
        record.with(status: :executed, result: result[:result])
      else
        record.with(status: :failed, error: result[:error])
      end

      consequence_text = resolve_consequence(record, result, memory_store)
      record = record.with(consequence: consequence_text) if consequence_text

      memory_store.update_section(name: MemoryKinds::ACTIONS, content: record.to_h, append: true)
      completed << record
    end

    completed
  end

  def resolve_consequence(action_record, tool_result, memory_store)
    prompt = OutcomePrompt.new
    context = {
      action: action_record.to_h,
      result: tool_result,
      scene: memory_store.get_section(MemoryKinds::CURRENT_SCENE)
    }
    response = prompt.execute(prompt: self.prompt, context: context)
    response.is_a?(Hash) ? response["consequence"] || response[:consequence] : nil
  end

  def generate_narrative(completed_actions, memory_store)
    prompt = NarrativePrompt.new
    context_tool = CurrentContextTool.new(sandbox_path: sandbox_path)
    current_context = context_tool.execute(path: memory_store.path)[:result] rescue {}
    base_context = {
      actions: completed_actions.map(&:to_h),
      current_context: current_context
    }

    context = if exceeds_context_limit?(base_context)
      compression = ContextCompressionTool.new(sandbox_path: sandbox_path).execute(path: memory_store.path) rescue {}
      compressed = compression[:result] || {}
      {
        actions: base_context[:actions],
        compressed_context: compressed[:overall_summary],
        sections: compressed[:sections]
      }
    else
      base_context
    end

    prompt.execute(prompt: self.prompt, context: context)
  end

  def symbolize_keys(hash)
    hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
  end

  def exceeds_context_limit?(context)
    approx_tokens = JSON.generate(context).size / 4.0
    approx_tokens > NarrativePrompt::CONTEXT_TOKEN_MAX
  end

  def system_prompt(extra)
    return DEFAULT_SYSTEM_PROMPT unless extra&.strip&.length&.positive?

    "#{DEFAULT_SYSTEM_PROMPT}\n\n#{extra}".strip
  end
end
