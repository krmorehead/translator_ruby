# ThoughtExtractor

## Purpose

Service to extract and filter `<think>...</think>` tags from LLM responses. Separates reasoning content from final output for cleaner responses and potential training data collection.

## Location

`app/services/thought_extractor.rb`

## Class Methods

### `extract_and_filter(content)`

Extracts and removes think tags from content.

**Parameters:**
- `content` (String): The LLM response content

**Returns:**
- Hash with:
  - `:content` - Filtered content with think tags removed
  - `:thoughts` - Extracted think tag content (or nil if none found)

**Example:**
```ruby
content = "<think>Let me reason about this</think>The final answer is 42"
result = ThoughtExtractor.extract_and_filter(content)

result[:content]  # => "The final answer is 42"
result[:thoughts] # => "Let me reason about this"
```

## Implementation Details

- Uses regex pattern `/<think>(.*?)<\/think>/m` for extraction
- Handles multiple think blocks (concatenates with newlines)
- Handles nested or malformed tags gracefully
- Trims whitespace from filtered content
- Returns nil for thoughts if no think tags found
- Falls back to returning original content if extraction fails

## Usage

ThoughtExtractor is called automatically by `GenericLlmClient::ClientRetryWrapper` to filter all LLM responses. Direct usage is typically not needed but available for testing or special cases.

## Testing

See `test/services/thought_extractor_test.rb` for comprehensive test coverage including:
- Single and multiple think blocks
- Multi-line content
- Malformed tags
- JSON preservation
- Real vllm-style responses

