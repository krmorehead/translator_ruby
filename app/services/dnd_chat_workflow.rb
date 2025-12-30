# frozen_string_literal: true

# Workflow orchestrating DnD chat using goal-driven agentic planning.
#
# Uses DndAgentWorker for flexible LLM-driven action selection:
# 1. Understands player intent
# 2. Plans and executes actions until intent is satisfied
# 3. Generates narrative response
#
# State Flow:
#   pending → running → planning → executing → evaluating ─┐
#                          ↑                               │
#                          └─── continue (intent unclear) ─┘
#                                        │
#                                        └─── intent_satisfied → narrating → complete
class DndChatWorkflow < BaseWorkflow
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a DnD assistant with access to tools (memory, inventory, dice, skill checks, etc.).
    Respond by selecting appropriate tools and narrating outcomes in a story-focused way.
  PROMPT

  DEFAULT_PATH = File.join("tmp", "dnd_chat_sandbox")

  def self.workflow_name
    "dnd_chat"
  end

  attr_reader :agent_path

  def initialize(memory_store_class: MemoryStore, path: nil)
    super()
    @memory_store_class = memory_store_class
    @agent_path = path || DEFAULT_PATH
  end

  # Orchestrates the full workflow using the DndAgentWorker
  def execute
    trigger(:start)
    state = WorkflowState.new(status: WorkflowState::STATUSES[:running], prompt: prompt)

    FileUtils.mkdir_p(@agent_path) unless File.exist?(@agent_path)

    memory_store = build_memory_store

    agent = DndAgentWorker.new(
      goal: prompt,
      path: @agent_path,
      memory_store: memory_store,
      conversation: conversation
    )

    result = agent.execute

    # Extract results from agent
    narrative = result[:narrative]
    assistant_message = Message.new(source: "assistant", target: "user", message: narrative)
    conversation << assistant_message if conversation

    result_hash = {
      narrative: narrative,
      actions: result[:actions],
      conversation: conversation,
      thoughts: nil,
      agent_metadata: result[:metadata]
    }

    mark_complete(result_hash)
    state = state.with(status: WorkflowState::STATUSES[:complete], data: result_hash)
    state
  rescue => e
    mark_failed(e.message)
    WorkflowState.new(status: WorkflowState::STATUSES[:failed], error: e.message)
  end

  # Builds OpenAI chat parameters for direct tool selection (used by controller)
  # @deprecated Use execute() for full agentic workflow
  def chat_parameters(user_prompt:, model: nil, extra_system_prompt: nil, tools: ToolCallService.available_dnd_tools)
    tool_names = tools.map { |t| t[:function][:name] }

    params = {
      model: model || BasePrompt.new.model,
      messages: [
        { role: "system", content: system_prompt(extra_system_prompt) },
        { role: "user", content: user_prompt }
      ]
    }

    # Only add response_format if we have tools
    # vLLM rejects schemas with empty enums
    if tool_names.any?
      params[:response_format] = {
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
    end

    params
  end

  
  def build_memory_store
    path = File.join(@agent_path, "memory.json")
    @memory_store_class.new(path: path)
  end

  def system_prompt(extra)
    return DEFAULT_SYSTEM_PROMPT unless extra&.strip&.length&.positive?

    "#{DEFAULT_SYSTEM_PROMPT}\n\n#{extra}".strip
  end
end
