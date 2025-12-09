# frozen_string_literal: true

# Global guard to prevent LLM mocking/stubbing.
# - Rejects Faraday test adapter
# - Rejects WebMock/VCR if loaded
# - Checks OpenAI::Client connection before every chat call
# To bypass (not recommended), set ALLOW_LLM_MOCKS=true

if ENV["ALLOW_LLM_MOCKS"] != "true"
  if defined?(WebMock)
    raise "LLM mocking forbidden: WebMock loaded"
  end
  if defined?(VCR)
    raise "LLM mocking forbidden: VCR loaded"
  end

  module NoLlmMockingFaradayGuard
    def build_connection(*args)
      conn = super
      adapters = conn.builder.handlers.map(&:name)
      if adapters.any? { |name| name.include?("Faraday::Adapter::Test") }
        raise "LLM mocking forbidden: Faraday test adapter detected"
      end
      conn
    end
  end

  OpenAI::Client.prepend(NoLlmMockingFaradayGuard)
end
