# frozen_string_literal: true

# Rails-style singleton module for LLM client with optional retry.
module GenericLlmClient
  RETRY_ERRORS = [
    Faraday::ServerError,
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Net::ReadTimeout,
    Net::OpenTimeout
  ].freeze

  # Capability definitions mapping to model configs
  CAPABILITIES = {
    general_llm: {
      model_name: "./vllm/models/qwen3_30b_a3b_moe",
      port: 52003
    },
    tool_calling: {
      model_name: "./vllm/models/hivata____functionary__small__v3.2__AWQ/snapshots/bee9e4cae2fd117dfcc32780d7ac165074d2f679",
      port: 52004
    }
  }.freeze

  module_function

  # Get a client for the specified capability
  # @param capability [Symbol] The capability (:general_llm or :tool_calling)
  # @return [ClientRetryWrapper, nil] The LLM client for this capability
  def client_for(capability)
    @clients ||= {}
    @clients[capability] ||= build_client_for_capability(capability)
  end

  # Legacy instance method for backward compatibility
  def instance
    client_for(:general_llm)
  end

  def build_client_for_capability(capability)
    config = CAPABILITIES[capability]
    raise ArgumentError, "Unknown capability: #{capability}" unless config

    return nil unless ENV["API_KEY"].present? && ENV["LLM_URL"].present?

    url = build_url_for_capability(config[:port])
    client = OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: url,
      request_timeout: request_timeout
    )
    wrap_with_retry(client)
  end

  # Extract host from LLM_URL and replace port
  # @param port [Integer] The port for this capability
  # @return [String] The full URL with updated port
  def build_url_for_capability(port)
    base_url = ENV["LLM_URL"]
    uri = URI.parse(base_url)
    uri.port = port
    uri.to_s
  end

  # Get model name for a capability
  # @param capability [Symbol] The capability
  # @return [String] The model name
  def model_for(capability)
    config = CAPABILITIES[capability]
    raise ArgumentError, "Unknown capability: #{capability}" unless config
    config[:model_name]
  end

  def build_from_env
    build_client_for_capability(:general_llm)
  end

  def request_timeout
    ENV.fetch("LLM_REQUEST_TIMEOUT", 60).to_i
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
    ENV.fetch("LLM_RETRY_AT", 1).to_i
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
