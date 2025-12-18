# BasePrompt

## Purpose

Abstract base class for all LLM-backed prompts. Provides common functionality for executing prompts, formatting context, parsing responses, and context size validation.

## Location

`app/prompts/base_prompt.rb`

## Inheritance

Subclasses must implement:
- `response_schema`: Return JSON schema hash or nil for freeform text
- Optionally override `system_prompt`, `model`, `format_context`

## Constants

- `CHARS_PER_TOKEN = 4` - Approximate characters per token for context size estimation

## Initialization

```ruby
def initialize(tools: [])
```

**Parameters:**
- `tools`: Array of tool schemas (optional)

## Key Methods

### `max_safe_context`

Returns the maximum safe context size in tokens from `ENV.fetch("MAX_SAFE_CONTEXT")`.

**Raises:** `KeyError` if `MAX_SAFE_CONTEXT` environment variable is not defined.

### `execute(prompt:, context: {})`

Executes the prompt against the LLM and returns parsed response with thoughts.

**Context Size Validation:** Before executing, validates that the total context size (in estimated tokens) does not exceed `MAX_SAFE_CONTEXT`. Raises `ContextSizeExceededError` if exceeded.

**Parameters:**
- `prompt`: String - The user prompt text
- `context`: Hash - Context data to include (optional)

**Returns:** Hash with `:content` and `:thoughts` keys

```ruby
{
  content: parsed_content,    # JSON hash or string depending on schema
  thoughts: "extracted or nil"  # From think tag filtering
}
```

**For Prompts with `response_schema`:**
- `:content` contains the parsed JSON hash
- LLM response is validated against the schema

**For Prompts without `response_schema`:**
- `:content` contains the raw string response

**Example:**
```ruby
prompt = NarrativePrompt.new
result = prompt.execute(
  prompt: "Narrate the scene",
  context: { scene: "dark forest", actions: [...] }
)

narrative_text = result[:content]  # String
thoughts = result[:thoughts]        # String or nil
```

### `system_prompt`

Returns the system prompt string. Default implementation returns `BASE_SYSTEM_PROMPT`.

Subclasses typically override this to provide specialized instructions.

### `response_schema`

Must be implemented by subclasses. Returns JSON schema hash or nil.

### `format_context(context)`

Converts context hash into formatted string for LLM.

Default implementation uses `JSON.pretty_generate`.

### `model`

Returns model identifier from `ENV["LLM_MODEL"]`.

Subclasses can override to use different environment variables.

## Response Processing Flow

1. Execute LLM request via `GenericLlmClient`
2. Client automatically filters `<think>` tags and adds `thoughts` field
3. `parse_response` extracts content and thoughts
4. For schema-based prompts: Parse JSON and validate
5. For freeform prompts: Return string content
6. Return hash with both content and thoughts

## Accessing Results in Subclasses

When overriding `execute`, remember to handle the hash return:

```ruby
def execute(prompt:, context: {})
  result = super  # Returns { content: ..., thoughts: ... }
  
  # Access the content
  actions = result[:content]  # Already parsed/processed
  
  # Optionally pass through thoughts
  { content: process(actions), thoughts: result[:thoughts] }
end
```

## Backward Compatibility

The new hash return format requires updating code that calls prompts:

**Before:**
```ruby
result = prompt.execute(prompt: "...", context: {})
# result was direct content (string or hash)
```

**After:**
```ruby
result = prompt.execute(prompt: "...", context: {})
content = result[:content]  # Extract content
thoughts = result[:thoughts]  # Access thoughts if needed
```

## Error Handling

- Raises `ContextSizeExceededError` if estimated tokens exceed `MAX_SAFE_CONTEXT`
- Raises `KeyError` if `MAX_SAFE_CONTEXT` environment variable is not defined
- Raises "LLM client not configured" if client is nil
- Raises "Failed to parse LLM response as JSON" for schema validation errors
- Raises "LLM prompt execution failed" for other errors

## Context Size Validation

The `validate_context_size!` method estimates token count by dividing total characters by `CHARS_PER_TOKEN` (4). If the estimated tokens exceed `max_safe_context`, it raises `ContextSizeExceededError` with details:

```ruby
# Example error message:
"Context size (50000 tokens) exceeds MAX_SAFE_CONTEXT (32000 tokens). 
Total characters: 200000. Reduce context or increase MAX_SAFE_CONTEXT."
```

This prevents unbounded context growth that could cause LLM timeouts or excessive token usage.

## Environment Variables

- `LLM_MODEL` - Required. The model identifier for LLM requests.
- `MAX_SAFE_CONTEXT` - Required. Maximum context size in tokens.

## Testing

See `test/prompts/base_prompt_test.rb` and subclass tests for examples.

All tests updated to access `result[:content]` and verify `result[:thoughts]` presence.

