# frozen_string_literal: true

# Shared OpenAI client singleton for runtime and tests.
GenericLLMClient = if ENV["API_KEY"].present? && ENV["LLM_URL"].present?
  OpenAI::Client.new(
    access_token: ENV["API_KEY"],
    uri_base: ENV["LLM_URL"],
    request_timeout: 60
  )
else
  nil
end

