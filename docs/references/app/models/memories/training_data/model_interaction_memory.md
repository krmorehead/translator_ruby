# ModelInteractionMemory

## Purpose

Memory type for recording LLM model interactions including extracted thoughts. Designed for training data collection and analysis.

## Location

`app/models/memories/training_data/model_interaction_memory.rb`

## Class

`Memories::TrainingData::ModelInteractionMemory`

Inherits from `Memories::BaseMemory`

## Key Attributes

- **Section Name**: `MemoryKinds::MODEL_INTERACTIONS` ("model_interactions")
- **Weight**: 0.0 (metadata, not narrative content)
- **Default**: Empty array

## Class Methods

### `append(store:, interaction:)`

Appends a new model interaction to the memory store.

**Parameters:**
- `store` (MemoryStore): The memory store instance
- `interaction` (Hash): The interaction data containing:
  - `timestamp`: ISO8601 timestamp (auto-added if not present)
  - `request`: Hash with model, messages, parameters
  - `response`: Hash with content, finish_reason
  - `thoughts`: Extracted think content or nil

**Example:**
```ruby
interaction = {
  request: {
    model: "qwen3_30b",
    messages: [{ role: "user", content: "Hello" }]
  },
  response: {
    content: "Hi there!",
    finish_reason: "stop"
  },
  thoughts: "The user is greeting me"
}

Memories::TrainingData::ModelInteractionMemory.append(
  store: memory_store,
  interaction: interaction
)
```

### `to_h(store:)`

Returns array of all recorded interactions.

**Returns:** Array of interaction hashes

### `summarize(store:)`

Returns count of recorded interactions.

**Returns:** Hash with `:section` and `:summary` keys

## Future Enhancements

Planned additions (marked as TODO in code):
- Export interactions as training dataset
- Filter by date range
- Format conversion (JSONL, Parquet, etc.)

## Integration

Registered in `Memories::Registry` and `MemoryKinds::ALL`.
Can be used with `MemoryStore` like any other memory type.

## Testing

See `test/models/memories/training_data/model_interaction_memory_test.rb`

