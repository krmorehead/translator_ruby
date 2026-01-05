# frozen_string_literal: true

# Configuration for agent data storage paths
# Enforces strict OOP principles - no conditionals, no fallbacks
# FAILS LOUDLY if AGENT_DATA_PATH is not defined in environment
module AgentConfig
  class << self
    # Base directory for all agent data (memories, workflows, outputs)
    # This directory is created in the Rails root and is independent of
    # the working directory where agents investigate/modify code.
    #
    # MUST be set via AGENT_DATA_PATH environment variable in:
    # - .env.development
    # - .env.test
    # - .env.production
    #
    # NO fallbacks, NO conditionals - FAILS LOUDLY if not configured
    def data_path
      @data_path ||= begin
        # Use .fetch to fail loudly if AGENT_DATA_PATH not defined
        path = ENV.fetch("AGENT_DATA_PATH")
        FileUtils.mkdir_p(path) unless File.directory?(path)
        path
      end
    end
    
    # Set the data path (primarily for testing)
    # Validates input strictly - no nils, no empty strings
    def data_path=(path)
      raise ArgumentError, "path cannot be nil" if path.nil?
      raise ArgumentError, "path cannot be empty" if path.to_s.strip.empty?
      
      @data_path = path.to_s
      FileUtils.mkdir_p(@data_path) unless File.directory?(@data_path)
      @data_path
    end
    
    # Reset the cached path (for testing)
    def reset!
      @data_path = nil
    end
  end
end

