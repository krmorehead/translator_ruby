# TranslationContext

**File**: `app/models/translation_context.rb`

## Purpose

Plain Old Ruby Object (PORO) that encapsulates all parameters needed for a translation request. Acts as a data transfer object between controllers and services.

## Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `text` | String | nil | The text to be translated |
| `target_lang` | String | nil | Target language code (ISO 639) |
| `source_lang` | String | `"en"` | Source language code |
| `context` | String | nil | Contextual hint for translation (e.g., path in document) |
| `model_type` | String | nil | LLM model override |
| `formality` | String | `"formal"` | Formality level (formal, informal, default) |

## Implementation

```ruby
class TranslationContext
  attr_accessor :text, :target_lang, :source_lang, :context, :model_type, :formality

  def initialize(text: nil, target_lang: nil, source_lang: "en", 
                 context: nil, model_type: nil, formality: "formal")
    # ... attribute assignments
  end
end
```

## Usage

### Creating from Controller Parameters

```ruby
context = TranslationContext.new(
  text: params[:text],
  target_lang: params[:target_lang],
  source_lang: params[:source_lang] || "en",
  context: params[:context],
  formality: params[:formality] || "formal"
)
```

### Creating from Tree Traversal

```ruby
context = TranslationContext.new(
  text: "Hello",
  target_lang: @target_language,
  source_lang: "en",
  context: "greetings.welcome",  # Path in document tree
  formality: "formal"
)
```

## Design Notes

- **Not an ActiveRecord model**: No database persistence
- **Immutable-ish**: Uses attr_accessor but typically created once and passed through
- **Serialization-friendly**: All attributes are simple types

## Related Files

- [TranslationController](../controllers/api/v1/translation_controller.md) - Creates contexts from HTTP params
- [TranslationTreeService](../services/translation_tree_service.md) - Creates contexts during traversal
- [TranslationService](../services/translation_service.md) - Consumes contexts for translation
- `test/models/translation_context_test.rb` - Model tests


