# TranslationTreeService

**File**: `app/services/translation_tree_service.rb`

## Purpose

Traverses nested data structures (Hash, Array) and translates string leaf nodes. Supports both simple string leaves and structured `translation_hash` objects for fine-grained translation control.

## Initialization

```ruby
TranslationTreeService.new(
  target_language: "Spanish",       # Full language name
  protected_strings: ["Brightwheel"] # Terms to preserve
)
```

## Public Methods

### `traverse`

Recursively traverses a node structure and translates leaf nodes.

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `node` | Hash/Array/String | Current node to process |
| `translation_callback` | Proc/Lambda | Called with TranslationContext for each leaf |
| `path` | Array | Current path in tree (for context building) |

**Returns**: Translated structure matching input shape

## Node Types

### Hash Nodes

**Regular Hash**: Traverses each key-value pair recursively.

```ruby
{ "greeting" => "Hello", "farewell" => "Goodbye" }
# → { "greeting" => "Hola", "farewell" => "Adiós" }
```

**Translation Hash**: Special marker for per-node settings.

```ruby
{
  "translation_hash" => true,
  "text" => "Hello",
  "target_lang" => "French",
  "formality" => "informal"
}
# → "Salut"
```

### Array Nodes

Traverses each element, maintaining index in path.

```ruby
["Hello", "Goodbye"]
# → ["Hola", "Adiós"]
```

### String Nodes

Direct translation with default settings.

```ruby
"Hello"  # → "Hola"
```

### Other Types

Raises `ArgumentError` for unexpected types (Integer, Boolean, etc.).

## Translation Hash Schema

When a Hash contains `"translation_hash" => true`, it's treated as a leaf node with custom settings:

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `translation_hash` | Boolean | Yes | - | Must be `true` |
| `text` | String | Yes | - | Text to translate |
| `target_lang` | String | No | Service default | Override target language |
| `source_lang` | String | No | `"en"` | Source language |
| `context` | String | No | Auto-generated | Translation context |
| `model_type` | String | No | nil | LLM model override |
| `formality` | String | No | `"formal"` | Formality level |

## Context Path Building

Builds dot-notation paths for context:

```ruby
# Path: ["messages", "welcome", 0]
# Context: "messages.welcome.0"
```

This helps LLM understand where text appears in the document structure.

## Usage Example

```ruby
tree_service = TranslationTreeService.new(
  target_language: "Spanish",
  protected_strings: ["Brightwheel"]
)

translation_callback = ->(context) { 
  translation_service.translate_text(context) 
}

result = tree_service.traverse(document, translation_callback)
```

## Related Files

- [TranslationService](translation_service.md) - Uses this for document translation
- [TranslationContext](../models/translation_context.md) - Created for each leaf node
- `test/services/translation_tree_service_test.rb` - Service tests

