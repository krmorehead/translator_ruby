# TranslationService

**File**: `app/services/translation_service.rb`

## Purpose

Core service that handles all translation operations. Manages LLM client communication, document parsing, and coordinates with `TranslationTreeService` for document traversal.

## Initialization

```ruby
TranslationService.new(
  llm_url: "http://llm.example.com",  # Optional, defaults to ENV["LLM_URL"]
  timeout: 30,                         # Request timeout in seconds
  protected_strings: ["Brand"],        # Terms to preserve untranslated
  target_language: "es"                # Target language code
)
```

## Public Methods

### `translate_document`

Translates entire documents (Hash structures) by traversing and translating leaf nodes.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `doc_content` | String | Yes | Raw document content (JSON/YAML) |
| `input_format` | String | Yes | Input format hint |
| `export_format` | String | No | Output format (JSON/YAML) |
| `protected_strings` | Array | No | Additional terms to protect |
| `target_language` | String | No | Override target language |

**Returns**: String (formatted as JSON or YAML)

---

### `translate_text`

Translates a single text string using the LLM.

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `translation_context` | TranslationContext | Context object with text and settings |

**Returns**: String (translated text)

---

### `parse_document`

Parses raw document content into a Ruby Hash/Array structure.

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `doc` | String | Raw document content |
| `format_hint` | String | Format hint (json/yaml) |

**Returns**: Hash or Array

---

### `convert_to_yaml`

Converts parsed data to YAML-compatible structure.

---

### `convert_to_export_format`

Converts data to requested output format.

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `data` | Hash/Array | Data to format |
| `format` | String | "JSON" or "YAML" |

**Returns**: String

## LLM Integration

### System Prompt Construction

The service builds prompts that:
1. Specify target language
2. Include source language when provided
3. Set formality level
4. List protected terms (e.g., "Brightwheel")
5. Instruct preservation of `{variables}`

### Structured Output

Uses OpenAI's JSON schema response format:
```ruby
response_format: {
  type: "json_schema",
  json_schema: {
    name: "translation_response",
    schema: {
      type: "object",
      properties: {
        translation: { type: "string" }
      },
      required: ["translation"]
    }
  }
}
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `LLM_URL` | LLM backend URL | Required |
| `LLM_MODEL` | Model identifier | `qwen30b` |
| `API_KEY` | Authorization token | Required |

## Protected Terms

- Always protects "Brightwheel" by default
- Additional terms can be passed per-request
- Variables in `{curly_braces}` are preserved

## Language Handling

Uses `iso639` gem to convert language codes (e.g., "es") to full names (e.g., "Spanish") for clearer LLM prompts.

## Related Files

- [TranslationTreeService](translation_tree_service.md) - Tree traversal
- [TranslationContext](../models/translation_context.md) - Context object
- [TranslationController](../controllers/api/v1/translation_controller.md) - HTTP interface
- `test/services/translation_service_test.rb` - Service tests


