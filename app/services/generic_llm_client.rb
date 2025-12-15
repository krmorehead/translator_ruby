# frozen_string_literal: true

# Rails-style singleton module for LLM client with optional retry.
module GenericLlmClient
  RETRY_ERRORS = [
    Faraday::ServerError,
    Faraday::TimeoutError,
    Faraday::ConnectionFailed
  ].freeze

  module_function

  def instance
    @instance ||= build_from_env
  end

  def build_from_env
    return nil unless ENV["API_KEY"].present? && ENV["LLM_URL"].present?

    client = OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: ENV["LLM_URL"],
      request_timeout: 60
    )
    wrap_with_retry(client)
  end

  def wrap_with_retry(client)
    # Always wrap client for response processing (think tag filtering)
    # Default to 1 retry attempt if not specified
    attempts = retry_attempts
    attempts = 1 if attempts.zero?
    
    ClientRetryWrapper.new(client: client, attempts: attempts, delay: retry_delay)
  end

  def retry_enabled?
    retry_attempts > 0
  end

  def retry_attempts
    ENV.fetch("LLM_RETRY_ATTEMPTS", 1).to_i
  end

  def retry_delay
    ENV.fetch("LLM_RETRY_DELAY", 50).to_f * retry_attempts
  end

  class ClientRetryWrapper
    def initialize(client:, attempts:, delay:)
      @client = client
      @attempts = attempts
      @delay = delay
    end

    # Executes chat request with retry logic and processes response to extract thoughts.
    # Always filters <think> tags from content and adds thoughts field to response.
    def chat(parameters:)
      last_error = nil
      @attempts.times do |i|
        begin
          response = @client.chat(parameters: parameters)
          return process_response(response)
        rescue *GenericLlmClient::RETRY_ERRORS => e
          last_error = e
          sleep(@delay) if i < @attempts - 1
        end
      end
      raise last_error
    end

    private

    # Processes response to extract and filter think tags.
    # Returns modified response with filtered content and added thoughts field.
    def process_response(response)
      # Deep copy response to avoid mutating original
      processed = deep_copy(response)
      
      # Extract content from response
      content = processed.dig("choices", 0, "message", "content")
      return processed unless content

      # Extract and filter think tags
      result = ThoughtExtractor.extract_and_filter(content)

      # Debug logging in test environment
      if defined?(Rails) && Rails.env.test? && ENV["DEBUG_THOUGHT_FILTERING"] == "1"
        Rails.logger.debug "ThoughtExtractor - Original: #{content[0...100]}"
        Rails.logger.debug "ThoughtExtractor - Filtered: #{result[:content][0...100]}"
        Rails.logger.debug "ThoughtExtractor - Thoughts: #{result[:thoughts] ? 'present' : 'nil'}"
      end

      # Update content with filtered version
      processed["choices"][0]["message"]["content"] = result[:content]

      # Add thoughts field to top level of response
      processed["thoughts"] = result[:thoughts]

      processed
    end

    def deep_copy(obj)
      JSON.parse(JSON.generate(obj))
    end
  end
end
