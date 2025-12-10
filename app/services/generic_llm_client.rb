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
    return client unless retry_enabled?

    ClientRetryWrapper.new(client: client, attempts: retry_attempts, delay: retry_delay)
  end

  def retry_enabled?
    flag = ENV["LLM_RETRY"]
    return true if flag.nil?

    val = flag.to_s.strip.downcase
    return false if %w[false 0 off no].include?(val)

    val.present?
  end

  def retry_attempts
    [ENV.fetch("LLM_RETRY_ATTEMPTS", 3).to_i, 1].max
  end

  def retry_delay
    ENV.fetch("LLM_RETRY_DELAY", 1).to_f
  end

  class ClientRetryWrapper
    def initialize(client:, attempts:, delay:)
      @client = client
      @attempts = attempts
      @delay = delay
    end

    def chat(parameters:)
      last_error = nil
      @attempts.times do |i|
        begin
          return @client.chat(parameters: parameters)
        rescue *GenericLlmClient::RETRY_ERRORS => e
          last_error = e
          sleep(@delay) if i < @attempts - 1
        end
      end
      raise last_error
    end
  end
end

