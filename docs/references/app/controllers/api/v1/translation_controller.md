# TranslationController

**File**: `app/controllers/api/v1/translation_controller.rb`

## Purpose

Handles translation requests for both full documents and individual text strings. Delegates translation logic to `TranslationService`.

## Endpoints

### `POST /api/v1/translate`

Translates entire documents (JSON or YAML) to a target language.

**Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `doc_to_translate` | String | Yes | - | Document content to translate |
| `export_format` | String | No | `"JSON"` | Output format (JSON or YAML) |
| `target_language` | String | No | `"es"` | Target language code (ISO 639) |

**Headers**:
| Header | Purpose |
|--------|---------|
| `Content-Type` | Hints at input format (json/yaml) |

**Success Response**: Translated document in requested format

**Error Responses**:
| Status | Condition |
|--------|-----------|
| 400 | Missing `doc_to_translate`, invalid JSON/YAML, or invalid arguments |
| 500 | Translation service failure |

---

### `POST /api/v1/translate_text`

Translates a single text string with optional context and formatting options.

**Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | String | Yes | - | Text to translate |
| `target_lang` | String | Yes | - | Target language code |
| `source_lang` | String | No | `"en"` | Source language code |
| `context` | String | No | nil | Translation context hint |
| `model_type` | String | No | nil | LLM model override |
| `formality` | String | No | `"formal"` | Formality level |

**Success Response**:
```json
{
  "translation": "Translated text here"
}
```

**Error Responses**:
| Status | Condition |
|--------|-----------|
| 400 | Missing required parameters or invalid arguments |
| 500 | Translation service failure |

## Implementation Notes

- Creates `TranslationContext` objects for structured translation requests
- Delegates all translation logic to `TranslationService`
- Supports both JSON and YAML input/output formats
- Logs errors to Rails logger

## Related Files

- [TranslationService](../../services/translation_service.md) - Core translation logic
- [TranslationContext](../../models/translation_context.md) - Translation parameters model
- `test/controllers/api/v1/translation_controller_test.rb` - Controller tests

