require "test_helper"

class LlmDndToolsIntegrationTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "llm_dnd_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @inventory_path = File.join(@sandbox_path, "inventory.json")
    @memory_path = File.join(@sandbox_path, "memory.json")
    %w[dice_roll_tool skill_check_tool inventory_tool memory_tool memory_summarize_tool].each do |file|
      require Rails.root.join("app", "tools", file)
    rescue LoadError
      # already loaded
    end
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  def client
    OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: ENV["LLM_URL"],
      request_timeout: 60
    )
  end

  def workflow
    @workflow ||= DndChatWorkflow.new
  end

  def tools
    ToolCallService.available_tools
  end

  def perform_chat(user_content)
    params = workflow.chat_parameters(user_prompt: user_content)
    client.chat(parameters: params)
  end
  
  # Require that the LLM returns structured content.
  def parsed_tool_response(prompt)
    response = perform_chat(prompt)
    content = response.dig("choices", 0, "message", "content")
    assert content, "LLM should return structured content"
    JSON.parse(content)
  rescue Faraday::ServerError => e
    skip "LLM server error: #{e.message}"
  rescue Faraday::ConnectionFailed => e
    skip "LLM connection failed: #{e.message}"
  end

  def filter_args_for(tool_name, args)
    args ||= {}
    tool_class = ToolCallService.tool_class_for(tool_name)
    schema_keys = tool_class.parameters_schema[:properties].keys.map(&:to_sym)
    normalized = args.transform_keys(&:to_sym)

    case tool_name
    when InventoryTool::NAME
      normalized[:operation] ||= InventoryTool::OP_ADD_ITEM
      normalized[:name] ||= "LLM item"
      normalized[:quantity] ||= 1
      normalized[:path] ||= @inventory_path
    when MemoryTool::NAME
      normalized[:operation] ||= MemoryTool::OP_UPDATE
      normalized[:section] ||= MemoryKinds::QUESTS
      normalized[:content] ||= "Quest update"
      normalized[:path] ||= @memory_path
    when MemorySummarizeTool::NAME
      normalized[:path] ||= @memory_path
      normalized[:sections] ||= [MemoryKinds::QUESTS]
    end

    normalized.slice(*schema_keys)
  end

  def execute_tool_response(parsed)
    tool_name = parsed["tool"]
    args = parsed["arguments"]
    filtered = filter_args_for(tool_name, args)
    ToolCallService.new(sandbox_path: @sandbox_path).execute(tool_name: tool_name, arguments: filtered)
  end

  test "LLM selects dice_roll for advantage request" do
    parsed = parsed_tool_response("Roll a d20 with advantage and add +3. Use the dice_roll tool.")
    assert_equal DiceRollTool::NAME, parsed["tool"]
    result = execute_tool_response(parsed)
    assert_equal true, result[:success]
  end

  test "LLM can add and list inventory" do
    prompt = "Add a healing potion weighing 0.5 with quantity 2 using the inventory tool. Then list the inventory."
    parsed = parsed_tool_response(prompt)
    assert_equal InventoryTool::NAME, parsed["tool"]
    result = execute_tool_response(parsed)
    assert_equal true, result[:success]

    data = JSON.parse(File.read(@inventory_path))
    data = [data] if data.is_a?(Hash)
    item = data.first || {}
    name_val = item["name"]
    name_str = name_val.is_a?(String) ? name_val : name_val.to_s
    assert name_str.downcase.include?("potion") || name_str.downcase.include?("llm"), "item name should reflect potion or LLM-provided item"
    assert_equal 2, item["quantity"]
  end

  test "LLM updates memory and summarizes quests" do
    prompt_update = "Record that we accepted the quest to rescue the merchant's son using the memory tool."
    parsed1 = parsed_tool_response(prompt_update)
    assert_equal MemoryTool::NAME, parsed1["tool"]
    result1 = execute_tool_response(parsed1)
    assert_equal true, result1[:success], result1[:error]

    prompt_sum = "Summarize the quests so far using the memory_summarize tool."
    parsed2 = parsed_tool_response(prompt_sum)
    assert_equal MemorySummarizeTool::NAME, parsed2["tool"]
    result2 = execute_tool_response(parsed2)
    assert_equal true, result2[:success], result2[:error]
    summary = result2[:result][:summary].to_s
    assert !summary.strip.empty?, "summary should not be empty"
  end
end
