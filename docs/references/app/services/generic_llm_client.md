# GenericLlmClient

## Purpose

Rails-style singleton module for LLM client with automatic retry logic and think tag filtering.

## Location

`app/services/generic_llm_client.rb`

## Module Methods

### `instance`

Returns the configured LLM client instance (always wrapped for processing).

**Returns:** `ClientRetryWrapper` instance

### `build_from_env`

Builds a new client from environment variables and wraps it with retry and filtering logic.

**Environment Variables:**
- `API_KEY`: Authorization token (required)
- `LLM_URL`: LLM backend endpoint (required)
- `LLM_RETRY_ATTEMPTS`: Number of retry attempts (default: 1)
- `LLM_RETRY_DELAY`: Base delay for retries in milliseconds (default: 50)

## ClientRetryWrapper

The wrapper class that provides retry logic and think tag filtering.

### Think Tag Filtering

**All responses are automatically processed to:**
1. Extract `<think>...</think>` content from responses
2. Remove think tags from the content field
3. Add extracted thoughts as a `thoughts` field on the response

This happens transparently for all LLM calls.

### Response Structure

```ruby
# Before processing (from LLM)
{
  "choices" => [
    {
      "message" => {
        "content" => "<think>reasoning</think>actual response"
      }
    }
  ]
}

# After processing (returned to caller)
{
  "choices" => [
    {
      "message" => {
        "content" => "actual response"  # Think tags removed
      }
    }
  ],
  "thoughts" => "reasoning"  # NEW field
}
```

### `chat(parameters:)`

Executes a chat request with retry logic and response processing.

**Parameters:**
- `parameters`: Hash of OpenAI-compatible chat parameters

**Returns:** Processed response hash with filtered content and thoughts field

**Retry Behavior:**
- Retries on `Faraday::ServerError`, `Faraday::TimeoutError`, `Faraday::ConnectionFailed`
- Uses exponential backoff based on `LLM_RETRY_DELAY`
- Always wraps client (minimum 1 attempt) for response processing

## Integration with ThoughtExtractor

The wrapper uses `ThoughtExtractor.extract_and_filter` to process all responses. See [ThoughtExtractor documentation](thought_extractor.md) for details on the filtering logic.

## Usage

```ruby
client = GenericLlmClient.instance

response = client.chat(parameters: {
  model: "qwen3_30b",
  messages: [
    { role: "user", content: "Hello!" }
  ]
})

# Access filtered content
content = response.dig("choices", 0, "message", "content")

# Access extracted thoughts
thoughts = response["thoughts"]
```

## Testing

See `test/services/generic_llm_client_test.rb` for tests covering:
- Wrapper initialization
- Response processing
- Think tag filtering
- Retry logic
- Response structure preservation

