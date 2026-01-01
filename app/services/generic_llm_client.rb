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

  # Token thresholds for logging warnings
  TOKEN_THRESHOLDS = {
    info: 500,      # Log at info level above this
    warning: 2000,  # Log warning above this
    critical: 5000  # Log critical warning above this
  }.freeze

  # Approximate characters per token (conservative estimate)
  CHARS_PER_TOKEN = 4

  # Capability definitions mapping to model configs
  # All capabilities use LLM_URL (host) with different ports
  CAPABILITIES = {
    general_llm: {
      model_name: "./vllm/models/qwen3_32B_dense",
      port: 52003,
      max_context: 64000,
      base_url: "LLM_URL"
    },
    tool_calling: {
      model_name: "./vllm/models/qwen3_32B_dense",
      port: 52003,
      max_context: 64000,
      base_url: "LLM_URL"
    },
    embeddings: {
      model_name: "./vllm/models/all-MiniLM-L6-v2",
      port: 52005,  # Separate embedding model server
      max_context: 8191,  # Max tokens for embedding input
      base_url: "LLM_URL"
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
    base_url = ENV.fetch(config[:base_url], nil)
    raise "Base URL not found for capability: #{capability}" unless base_url
    url = build_url_for_capability(config[:port], base_url)
    client = OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: url,
      request_timeout: request_timeout
    )
    wrap_with_retry(client, capability: capability)
  end

  # Extract host from LLM_URL and replace port
  # @param port [Integer] The port for this capability
  # @return [String] The full URL with updated port
  def build_url_for_capability(port, base_url)
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

  def wrap_with_retry(client, capability: :general_llm)
    # Always wrap client for response processing (think tag filtering)
    # Default to 1 retry attempt if not specified
    attempts = retry_attempts
    attempts = 1 if attempts.zero?
    
    ClientRetryWrapper.new(client: client, attempts: attempts, delay: retry_delay, capability: capability)
  end

  def retry_enabled?
    retry_attempts > 0
  end

  def retry_attempts
    ENV.fetch("LLM_RETRY", "1").to_i
  end

  def retry_delay
    ENV.fetch("LLM_RETRY_DELAY", 50).to_f * retry_attempts
  end

  class ClientRetryWrapper
    def initialize(client:, attempts:, delay:, capability: :general_llm)
      @client = client
      @attempts = attempts
      @delay = delay
      @capability = capability
    end

    # Executes chat request with retry logic and processes response to extract thoughts.
    # Always filters <think> tags from content and adds thoughts field to response.
    def chat(parameters:)
      log_token_usage(parameters)

      last_error = nil
      @attempts.times do |i|
        begin
          response = @client.chat(parameters: parameters)
          return process_response(response)
        rescue *GenericLlmClient::RETRY_ERRORS => e
          last_error = e
          log_retry_attempt(i, e, parameters)
          sleep(@delay) if i < @attempts - 1
        end
      end
      raise last_error
    end

    # Generate embedding for text
    # @param text [String] Text to embed
    # @return [Embedding] Embedding domain object
    # @raise [TypeError] If text is not a String
    # @raise [ArgumentError] If text is empty
    def embed(text:)
      raise TypeError, "text must be a String, got #{text.class}" unless text.is_a?(String)
      raise ArgumentError, "text cannot be empty" if text.empty?

      parameters = {
        model: GenericLlmClient.model_for(@capability),
        input: text
      }

      last_error = nil
      @attempts.times do |i|
        begin
          response = @client.embeddings(parameters: parameters)
          vector = extract_embedding_vector(response)
          return Embedding.new(vector: vector, text: text)
        rescue *GenericLlmClient::RETRY_ERRORS => e
          last_error = e
          log(:warn, "Embedding retry attempt #{i + 1}/#{@attempts} after error: #{e.message}")
          sleep(@delay) if i < @attempts - 1
        end
      end
      raise last_error
    end

    private

    def extract_embedding_vector(response)
      raise TypeError, "Response must have data array" unless response.dig("data")
      raise TypeError, "Response data must be an Array" unless response["data"].is_a?(Array)
      raise ArgumentError, "Response data is empty" if response["data"].empty?
      
      embedding_data = response["data"][0]
      raise TypeError, "Embedding data must be a Hash" unless embedding_data.is_a?(Hash)
      raise ArgumentError, "Embedding missing 'embedding' key" unless embedding_data.key?("embedding")
      
      vector = embedding_data["embedding"]
      raise TypeError, "Embedding vector must be an Array" unless vector.is_a?(Array)
      
      vector
    end

    def log_token_usage(parameters)
      tokens = estimate_tokens(parameters)
      caller_info = extract_caller_info

      log_entry = "[LLM:#{@capability}] #{caller_info} - #{tokens} input tokens"

      if tokens > GenericLlmClient::TOKEN_THRESHOLDS[:critical]
        log(:warn, "⚠️  CRITICAL #{log_entry}")
      elsif tokens > GenericLlmClient::TOKEN_THRESHOLDS[:warning]
        log(:warn, "⚠️  HIGH #{log_entry}")
      elsif tokens > GenericLlmClient::TOKEN_THRESHOLDS[:info]
        log(:info, log_entry)
      else
        log(:debug, log_entry)
      end
    end

    def log_retry_attempt(attempt, error, parameters)
      tokens = estimate_tokens(parameters)
      caller_info = extract_caller_info
      log(:warn, "[LLM:#{@capability}] Retry #{attempt + 1}/#{@attempts} for #{caller_info} (#{tokens} tokens) - #{error.class}: #{error.message}")
    end

    def estimate_tokens(parameters)
      total_chars = 0

      # Count message content
      messages = parameters[:messages] || []
      messages.each do |msg|
        total_chars += (msg[:content] || msg["content"] || "").length
        total_chars += (msg[:role] || msg["role"] || "").length
      end

      # Count response schema if present
      if parameters[:response_format]
        total_chars += JSON.generate(parameters[:response_format]).length
      end

      # Count tools if present
      if parameters[:tools]
        total_chars += JSON.generate(parameters[:tools]).length
      end

      (total_chars.to_f / GenericLlmClient::CHARS_PER_TOKEN).ceil
    end

    def extract_caller_info
      # Walk up the call stack to find the prompt class
      caller_locations(5, 20).each do |loc|
        path = loc.path
        next if path.include?("generic_llm_client")
        next if path.include?("ruby/")
        next if path.include?("gems/")

        if path.include?("prompts/")
          # Extract prompt class name from path
          match = path.match(%r{prompts/(.+)\.rb})
          return match[1].camelize if match
        elsif path.include?("workflows/")
          match = path.match(%r{workflows/(.+)\.rb})
          return "Workflow::#{match[1].camelize}" if match
        elsif path.include?("workers/")
          match = path.match(%r{workers/(.+)\.rb})
          return "Worker::#{match[1].camelize}" if match
        end
      end
      "Unknown"
    end

    def log(level, message)
      Rails.logger.send(level, message)
    end

    # Processes response to extract and filter think tags.
    # Returns modified response with filtered content and added thoughts field.
    # ALL keys are symbolized at this boundary between LLM and application.
    def process_response(response)
      # Deep copy response to avoid mutating original
      processed = deep_copy_with_symbols(response)
      
      # Extract content from response
      content = processed.dig(:choices, 0, :message, :content)
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
      processed[:choices][0][:message][:content] = result[:content]

      # Add thoughts field to top level of response
      processed[:thoughts] = result[:thoughts]

      processed
    end

    # Deep copy with symbolized keys - handles the boundary between LLM (strings) and app (symbols)
    def deep_copy_with_symbols(obj)
      JSON.parse(JSON.generate(obj), symbolize_names: true)
    end
  end
end
