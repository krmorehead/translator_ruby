# frozen_string_literal: true

# Represents a D&D game session with persistent state
# Manages conversation, memory, and the DndAgentWorker
class DndSession
  attr_reader :session_id, :worker

  def initialize(session_id:)
    @session_id = session_id
    
    # Generate random D&D scenario on session creation
    scenario = generate_random_scenario
    
    @worker = DndAgentWorker.new(
      goal: scenario[:goal],
      owner_id: session_id
    )
    
    # Initialize agent to create memory store
    @worker.send(:initialize_agent)
    
    # Initialize memory with the generated scenario
    @worker.memory_store.set_section(MemoryKinds::CURRENT_SCENE, scenario[:scene])
    @worker.memory_store.set_section(MemoryKinds::MAIN_QUEST, scenario[:quest])
  end

  # Process a user message
  def process_message(message)
    @worker.process_message(message)
  end

  # Get conversation
  def conversation
    @worker.conversation
  end

  # Check if session exists on disk
  def exists?
    @worker.memory_store.respond_to?(:exists?) && @worker.memory_store.exists?
  end
  
  private
  
  def generate_random_scenario
    prompt = DndScenarioGenerationPrompt.new
    context = Contexts::BaseContext.new  # Empty context for scenario generation
    result = prompt.execute(prompt: "Generate a random D&D starting scenario", context: context)
    result[:content]
  end
end

