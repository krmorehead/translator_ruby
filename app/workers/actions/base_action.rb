# frozen_string_literal: true

module Actions
  # Base class for all agent actions
  # Actions wrap tools and provide a consistent interface for agent execution
  class BaseAction
    attr_reader :agent, :memory_store, :goal
    
    def initialize(agent:, memory_store:, goal:)
      @agent = agent
      @memory_store = memory_store
      @goal = goal
    end
    
    # Execute the action with given arguments
    # @return [Hash] Result with :success, :result, :summary keys
    def execute(**args)
      raise NotImplementedError, "#{self.class.name} must implement #execute"
    end
    
    protected
    
    # Helper to build success result
    def success_result(result, summary: nil)
      {
        success: true,
        result: result,
        summary: summary || result.to_s
      }
    end
    
    # Helper to build error result
    def error_result(message)
      {
        success: false,
        result: nil,
        error: message,
        summary: "Error: #{message}"
      }
    end
  end
end
