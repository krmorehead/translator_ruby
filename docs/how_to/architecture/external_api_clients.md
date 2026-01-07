---
description: External API client patterns with request/response serializers
globs: app/clients/**/*.rb
alwaysApply: false
---

# External API Client Patterns

**Tags**: [architecture, coding, back_end]  
**Applies To**: API clients for external systems (LLMs, third-party APIs)  
**Date**: 2026-01-06

## Overview

External API clients handle communication with third-party systems like LLMs, payment processors, or external services. These clients use request serializers to transform domain objects into the external API's format, and response deserializers to transform responses back into domain objects.

## External API Architecture

```
External API Client System
│
├── Client (orchestrates requests)
│   ├── Validates inputs
│   ├── Uses request serializer
│   ├── Makes HTTP request
│   ├── Uses response deserializer
│   └── Returns domain objects
│
├── Request Serializer (domain → external format)
│   ├── Inherits from base serializer
│   ├── Reads domain object via getters
│   ├── Transforms to external API format
│   └── Returns hash/JSON for HTTP body
│
├── Response Deserializer (external format → domain)
│   ├── Reads response JSON (string keys)
│   ├── Validates required fields
│   ├── Transforms to domain objects
│   └── Returns typed domain objects
│
└── Flow
    ├── Domain Object → Request Serializer → JSON
    ├── JSON → HTTP → External API
    ├── External API → HTTP → JSON
    └── JSON → Response Deserializer → Domain Object

Key Differences from API Serializers:
├── Request/Response pair (not just response)
├── Inheritance hierarchy for reuse
├── String key access (external APIs use strings)
└── Client owns serialization logic
```

---

## Rules

### [EXT][!CLIENT-ORCHESTRATION]

**Rule**: Clients orchestrate the full request/response cycle. Clients own serializers.

**Good Example:**

```ruby
# typed: strict

class LlmClient
  extend T::Sig
  
  sig { params(http_client: HttpClient, base_url: String).void }
  def initialize(http_client:, base_url:)
    @id = T.let(UUID.generate, UUID)
    @http_client = T.let(http_client, HttpClient)
    @base_url = T.let(base_url, String)
    @request_serializer = T.let(ChatRequestSerializer.new, ChatRequestSerializer)
    @response_deserializer = T.let(ChatResponseDeserializer.new, ChatResponseDeserializer)
  end
  
  sig { params(messages: T::Array[Message], model: String).returns(ChatResponse) }
  def chat(messages:, model:)
    # 1. Validate
    raise ArgumentError, "messages must be an Array" unless messages.is_a?(Array)
    raise ArgumentError, "model must be a String" unless model.is_a?(String)
    
    # 2. Serialize request
    request_body = @request_serializer.serialize(messages: messages, model: model)
    
    # 3. Make HTTP request
    response = @http_client.post(
      "#{@base_url}/chat/completions",
      body: request_body.to_json,
      headers: {"Content-Type" => "application/json"}
    )
    
    # 4. Deserialize response
    response_json = JSON.parse(response.body)
    @response_deserializer.deserialize(response_json)
  end
end
```

**Why**: Clients encapsulate the full external API interaction, keeping serialization concerns internal.

---

### [EXT][!REQUEST-SERIALIZERS]

**Rule**: Request serializers inherit from a base class and transform domain objects to external format.

**Good Example:**

```ruby
# typed: strict

# Base request serializer
class BaseRequestSerializer
  extend T::Sig
  
  sig { void }
  def initialize
    @id = T.let(UUID.generate, UUID)
  end
  
  sig { returns(String) }
  def api_version
    "v1"
  end
  
  sig { returns(T::Hash[String, String]) }
  def common_headers
    {
      "api-version" => api_version,
      "request-id" => @id.to_s
    }
  end
end

# Specific request serializer
class ChatRequestSerializer < BaseRequestSerializer
  extend T::Sig
  
  sig { params(messages: T::Array[Message], model: String, temperature: Float).returns(T::Hash[String, T.untyped]) }
  def serialize(messages:, model:, temperature: 0.7)
    {
      "model" => model,
      "messages" => messages.map { |msg| serialize_message(msg) },
      "temperature" => temperature,
      "metadata" => {
        "request_id" => @id.to_s,
        "timestamp" => Time.now.utc.iso8601
      }
    }
  end
  
  private
  
  sig { params(message: Message).returns(T::Hash[String, String]) }
  def serialize_message(message)
    {
      "role" => message.role,
      "content" => message.content
    }
  end
end
```

**Why**: Inheritance allows reuse of common patterns while specializing for specific endpoints.

---

### [EXT][!RESPONSE-DESERIALIZERS]

**Rule**: Response deserializers read string keys and return domain objects. Never use symbol access.

**Good Example:**

```ruby
# typed: strict

# Base response deserializer
class BaseResponseDeserializer
  extend T::Sig
  
  sig { void }
  def initialize
    @id = T.let(UUID.generate, UUID)
  end
  
  sig { params(response: T::Hash[String, T.untyped], key: String).returns(T.untyped) }
  def fetch_required(response, key)
    unless response.key?(key)
      raise ArgumentError, "Missing required field: #{key}"
    end
    response[key]
  end
end

# Specific response deserializer
class ChatResponseDeserializer < BaseResponseDeserializer
  extend T::Sig
  
  sig { params(response: T::Hash[String, T.untyped]).returns(ChatResponse) }
  def deserialize(response)
    # ✅ String access throughout
    choices = fetch_required(response, "choices")
    usage = fetch_required(response, "usage")
    
    first_choice = choices[0]
    message_data = fetch_required(first_choice, "message")
    
    message = Message.new(
      role: message_data["role"],
      content: message_data["content"]
    )
    
    token_usage = TokenUsage.new(
      prompt_tokens: usage["prompt_tokens"],
      completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"]
    )
    
    ChatResponse.new(
      message: message,
      usage: token_usage,
      model: response["model"]
    )
  end
end
```

**Why**: External APIs use string keys. String access prevents symbol/string mismatch errors.

---

### [EXT][!STRING-KEYS-ONLY]

**Rule**: Never symbolize keys from external APIs. Always use string access.

**Bad Example:**

```ruby
# ❌ Symbolizing external response
response_json = JSON.parse(response.body)
symbolized = response_json.deep_symbolize_keys

content = symbolized[:choices][0][:message][:content]  # ❌ Symbol access
```

**Good Example:**

```ruby
# ✅ String access
response_json = JSON.parse(response.body)

choices = response_json["choices"]
first_choice = choices[0]
message = first_choice["message"]
content = message["content"]  # ✅ String access
```

**Why**: String keys are the external API's contract. Symbolizing masks mismatches and adds overhead.

---

### [EXT][!INHERITANCE-HIERARCHY]

**Rule**: Use inheritance for request/response serializers to share common logic.

**Good Example:**

```ruby
# typed: strict

# Base classes
class BaseRequestSerializer
  extend T::Sig
  
  sig { void }
  def initialize
    @id = T.let(UUID.generate, UUID)
  end
  
  sig { returns(T::Hash[String, String]) }
  def metadata
    {
      "request_id" => @id.to_s,
      "timestamp" => Time.now.utc.iso8601
    }
  end
end

class BaseResponseDeserializer
  extend T::Sig
  
  sig { void }
  def initialize
    @id = T.let(UUID.generate, UUID)
  end
  
  sig { params(response: T::Hash[String, T.untyped], key: String).returns(T.untyped) }
  def fetch_required(response, key)
    unless response.key?(key)
      raise ArgumentError, "Missing required field: #{key}"
    end
    response[key]
  end
end

# Specialized serializers
class CompletionRequestSerializer < BaseRequestSerializer
  extend T::Sig
  
  sig { params(prompt: String, model: String).returns(T::Hash[String, T.untyped]) }
  def serialize(prompt:, model:)
    {
      "model" => model,
      "prompt" => prompt,
      "metadata" => metadata  # From base class
    }
  end
end

class CompletionResponseDeserializer < BaseResponseDeserializer
  extend T::Sig
  
  sig { params(response: T::Hash[String, T.untyped]).returns(CompletionResponse) }
  def deserialize(response)
    choices = fetch_required(response, "choices")  # From base class
    
    CompletionResponse.new(
      text: choices[0]["text"],
      model: response["model"]
    )
  end
end
```

**Why**: Base classes provide common utilities while keeping specific APIs flexible.

---

## Patterns

### Pattern: Complete LLM Client

```ruby
# typed: strict

class OpenAiClient
  extend T::Sig
  
  sig { params(api_key: String, base_url: String).void }
  def initialize(api_key:, base_url: "https://api.openai.com/v1")
    @id = T.let(UUID.generate, UUID)
    @api_key = T.let(api_key, String)
    @base_url = T.let(base_url, String)
    @http_client = T.let(HttpClient.new, HttpClient)
  end
  
  sig { params(messages: T::Array[Message], model: String, temperature: Float).returns(ChatResponse) }
  def chat(messages:, model:, temperature: 0.7)
    # Validation
    raise ArgumentError, "messages must be an Array" unless messages.is_a?(Array)
    raise ArgumentError, "messages cannot be empty" if messages.empty?
    
    # Serialize request
    serializer = ChatRequestSerializer.new
    request_body = serializer.serialize(
      messages: messages,
      model: model,
      temperature: temperature
    )
    
    # Make request
    response = @http_client.post(
      "#{@base_url}/chat/completions",
      body: request_body.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@api_key}"
      }
    )
    
    # Handle errors
    unless response.success?
      raise ApiError, "API request failed: #{response.status}"
    end
    
    # Deserialize response
    response_json = JSON.parse(response.body)
    deserializer = ChatResponseDeserializer.new
    deserializer.deserialize(response_json)
  end
end

# Request serializer
class ChatRequestSerializer < BaseRequestSerializer
  extend T::Sig
  
  sig { params(messages: T::Array[Message], model: String, temperature: Float).returns(T::Hash[String, T.untyped]) }
  def serialize(messages:, model:, temperature:)
    {
      "model" => model,
      "messages" => messages.map { |msg|
        {
          "role" => msg.role,
          "content" => msg.content
        }
      },
      "temperature" => temperature,
      "metadata" => metadata
    }
  end
end

# Response deserializer
class ChatResponseDeserializer < BaseResponseDeserializer
  extend T::Sig
  
  sig { params(response: T::Hash[String, T.untyped]).returns(ChatResponse) }
  def deserialize(response)
    choices = fetch_required(response, "choices")
    usage = fetch_required(response, "usage")
    
    first_choice = choices[0]
    message_data = fetch_required(first_choice, "message")
    
    message = Message.new(
      role: message_data["role"],
      content: message_data["content"]
    )
    
    token_usage = TokenUsage.new(
      prompt_tokens: usage["prompt_tokens"],
      completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"]
    )
    
    ChatResponse.new(
      id: response["id"],
      message: message,
      usage: token_usage,
      model: response["model"]
    )
  end
end

# Usage
client = OpenAiClient.new(api_key: ENV["OPENAI_API_KEY"])
messages = [
  Message.new(role: "user", content: "Hello!")
]
response = client.chat(messages: messages, model: "gpt-4")
puts response.message.content
```

---

### Pattern: Multi-Endpoint Client

```ruby
# typed: strict

class PaymentClient
  extend T::Sig
  
  sig { params(api_key: String).void }
  def initialize(api_key:)
    @id = T.let(UUID.generate, UUID)
    @api_key = T.let(api_key, String)
    @http_client = T.let(HttpClient.new, HttpClient)
    @base_url = T.let("https://api.payment.com/v1", String)
  end
  
  sig { params(amount: Integer, currency: String).returns(Charge) }
  def create_charge(amount:, currency:)
    serializer = ChargeRequestSerializer.new
    request_body = serializer.serialize(amount: amount, currency: currency)
    
    response = post("/charges", request_body)
    
    deserializer = ChargeResponseDeserializer.new
    deserializer.deserialize(JSON.parse(response.body))
  end
  
  sig { params(charge_id: String).returns(Charge) }
  def get_charge(charge_id:)
    response = get("/charges/#{charge_id}")
    
    deserializer = ChargeResponseDeserializer.new
    deserializer.deserialize(JSON.parse(response.body))
  end
  
  sig { params(charge_id: String).returns(Refund) }
  def refund_charge(charge_id:)
    serializer = RefundRequestSerializer.new
    request_body = serializer.serialize(charge_id: charge_id)
    
    response = post("/refunds", request_body)
    
    deserializer = RefundResponseDeserializer.new
    deserializer.deserialize(JSON.parse(response.body))
  end
  
  private
  
  sig { params(path: String, body: T::Hash[String, T.untyped]).returns(HttpResponse) }
  def post(path, body)
    @http_client.post(
      "#{@base_url}#{path}",
      body: body.to_json,
      headers: auth_headers
    )
  end
  
  sig { params(path: String).returns(HttpResponse) }
  def get(path)
    @http_client.get(
      "#{@base_url}#{path}",
      headers: auth_headers
    )
  end
  
  sig { returns(T::Hash[String, String]) }
  def auth_headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}"
    }
  end
end
```

---

## Checklist

- [ ] Client owns request and response serializers
- [ ] Request serializers inherit from base
- [ ] Response deserializers inherit from base
- [ ] String keys only (no symbolization)
- [ ] Validation in client before serialization
- [ ] Error handling in client
- [ ] Domain objects in, domain objects out
- [ ] Serializers read via getters only
- [ ] Type signatures on all methods
- [ ] UUID on all classes

---

## Summary

**Key Principles:**

1. **Client orchestration** - Client owns full request/response cycle
2. **Inheritance hierarchy** - Base classes for common logic
3. **String keys only** - Never symbolize external responses
4. **Request serializers** - Domain → external format
5. **Response deserializers** - External format → domain
6. **Domain boundaries** - Objects in, objects out

**Benefits:**

- Clear separation from internal API serializers
- Reusable patterns across endpoints
- Type-safe external API calls
- Testable in isolation
- Error handling at boundary

**When to Use:**

- LLM API clients
- Payment processor clients
- Third-party API integrations
- Any external HTTP API

