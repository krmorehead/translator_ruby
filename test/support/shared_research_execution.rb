# frozen_string_literal: true

# Global shared research execution for tests
# Runs ONCE at test suite start, reused by all tests that need research results
# Prevents overwhelming the LLM server with parallel research requests
module SharedResearchExecution
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  class << self
    attr_accessor :result, :computed, :mutex

    def shared_result
      @mutex ||= Mutex.new
      return @result if @computed

      @mutex.synchronize do
        # Double-check inside mutex
        return @result if @computed

        output_path = Rails.root.join("tmp", "shared_research_#{Process.pid}").to_s
        FileUtils.mkdir_p(output_path)

        original_output = ENV["RESEARCH_OUTPUT_PATH"]
        original_state = ENV["AGENT_STATE_PATH"]

        begin
          ENV["RESEARCH_OUTPUT_PATH"] = output_path
          ENV["AGENT_STATE_PATH"] = output_path

          worker = CodebaseResearcher.new(
            goal: "How does Calculator work? What is the relationship between Formatter and Calculator?",
            path: FIXTURE_PATH,
            max_depth: 2,
            output_modes: [:report, :documentation]
          )

          @result = worker.execute
          @computed = true
        ensure
          ENV["RESEARCH_OUTPUT_PATH"] = original_output
          ENV["AGENT_STATE_PATH"] = original_state
        end

        @result
      end
    end

    def reset!
      @mutex&.synchronize do
        @result = nil
        @computed = false
      end
    end
  end
end

