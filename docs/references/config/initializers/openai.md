# OpenAI Initializer

**File**: `config/initializers/openai.rb`

## Purpose

Loads the OpenAI gem for LLM client functionality. The actual client configuration happens in `TranslationService` using environment variables.

## Implementation

```ruby
require "openai"
```

## Configuration

The OpenAI client is configured at runtime in `TranslationService`:

```ruby
OpenAI::Client.new(
  access_token: ENV["API_KEY"],
  uri_base: ENV["LLM_URL"],
  request_timeout: 30
)
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `API_KEY` | Authorization token for LLM API |
| `LLM_URL` | Base URL for the LLM backend |
| `LLM_MODEL` | Model identifier (default: `qwen30b`) |

## Notes

- Uses the `ruby-openai` gem
- Supports OpenAI-compatible APIs (not just OpenAI)
- Client is created per-request in `TranslationService`

## Related Files

- [TranslationService](../../app/services/translation_service.md) - Uses OpenAI client
- `Gemfile` - Defines `ruby-openai` dependency

