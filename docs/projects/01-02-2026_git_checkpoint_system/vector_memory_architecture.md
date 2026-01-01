# Vector-Based Memory Retrieval Architecture

## Overview

Implementing semantic memory retrieval using LLM-generated embeddings for intelligent context querying between parent and child workflows.

## Core Components

### 1. Domain Objects

#### Embedding (`app/models/embedding.rb`) ✅
- Immutable value object containing vector + metadata
- 1536-dimensional vector (OpenAI text-embedding-3-small standard)
- Built-in `similarity_to` method for cosine similarity
- Serialization support via `to_h` / `from_h`
- Strict type validation, no defensive checks

#### WorkflowMemories::BaseMemory ✅
- Base class for all workflow memory entries
- Lazy-loaded `embedding` with memoization
- Abstract `vectorizable_content` method
- `similarity_to(other)` for comparing memories
- Checkpoint ID and timestamp tracking

#### WorkflowMemories::Decision ✅
- Specific memory type for decisions
- Vectorizes: "Decision: X. Rationale: Y. State: Z"
- Avoids redundant structure, focuses on semantic content
- Full serialization support

**TODO: Create additional memory types:**
- `StateTransition` - workflow state changes
- `Context` - context additions
- `Error` - error occurrences
- `Output` - workflow outputs

### 2. Services

#### VectorizationService (`app/services/vectorization_service.rb`) ✅
- Generates `Embedding` objects from text
- Uses `GenericLlmClient` with `:embeddings` capability
- `find_similar` method for threshold-based filtering
- Default similarity threshold: 0.70 (70%)
- Returns domain objects, not hashes

#### GenericLlmClient Updates ✅
- Added `:embeddings` capability (port 52004)
- `ClientRetryWrapper#embed(text:)` method
- Returns `Embedding` domain object
- Strict type validation on response
- Retry logic for resilience

### 3. Memory Store Integration

#### Current State
`WorkflowMemoryStore` stores raw hashes in arrays:
```ruby
def record_decision(decision:, rationale:, context: {})
  entry = {
    decision: decision,
    rationale: rationale,
    context: context,
    checkpoint_id: current_checkpoint_id
  }
  @sections[:decisions] << entry
end
```

#### Target State
Store domain objects with lazy embedding generation:
```ruby
def record_decision(decision:, rationale:, context: {})
  memory = WorkflowMemories::Decision.new(
    decision: decision,
    rationale: rationale,
    context: context,
    checkpoint_id: current_checkpoint_id,
    state: current_state
  )
  @sections[:decisions] << memory
  save!
  memory
end
```

### 4. Semantic Query

#### Current: Keyword-based
```ruby
def query_parent(*section_names)
  result = {}
  section_names.each do |name|
    data = parent_memory.get_section(name)
    result[name] = data if data
  end
  result
end
```

#### Target: Vector-based
```ruby
def query_similar_memories(query_text:, threshold: 0.70)
  raise TypeError, "query_text must be a String" unless query_text.is_a?(String)
  raise ArgumentError, "query_text cannot be empty" if query_text.empty?
  raise RuntimeError, "parent_memory is required" unless parent_memory

  # Generate query embedding
  query_embedding = vectorization_service.vectorize(text: query_text)

  # Collect all parent memories
  all_memories = parent_memory.all_memories

  # Find similar memories above threshold
  vectorization_service.find_similar(
    query_embedding: query_embedding,
    memories: all_memories,
    threshold: threshold
  )
end
```

## Implementation Steps

### Phase 1: Complete Domain Objects ⏳
1. ✅ Create `Embedding` model
2. ✅ Create `WorkflowMemories::BaseMemory`
3. ✅ Create `WorkflowMemories::Decision`
4. ⏳ Create remaining memory types (StateTransition, Context, Error, Output)
5. ⏳ Add tests for all domain objects

### Phase 2: Service Integration ⏳
1. ✅ Update `GenericLlmClient` with embeddings capability
2. ✅ Create `VectorizationService`
3. ⏳ Add comprehensive service tests
4. ⏳ Test embedding generation end-to-end

### Phase 3: Memory Store Refactoring ⏳
1. ⏳ Update `WorkflowMemoryStore#record_*` methods to create domain objects
2. ⏳ Update serialization (`to_h`, `load_sections`) to handle objects
3. ⏳ Add `all_memories` method to collect memories across sections
4. ⏳ Implement `query_similar_memories` with vector search
5. ⏳ Deprecate old `query_parent(*section_names)` method
6. ⏳ Update all call sites to use new API

### Phase 4: Testing & Validation ⏳
1. ⏳ Unit tests for each memory type
2. ⏳ Integration tests for vector search
3. ⏳ Performance testing (embedding generation speed)
4. ⏳ Accuracy testing (similarity threshold tuning)

## OOP Patterns Applied

### Required Parameters
- All memory constructors require all parameters
- No optional/nil defaults
- Fail fast with clear errors

### Immutable Domain Objects
- All memory objects are frozen after initialization
- Embeddings are frozen value objects
- No mutation after creation

### Lazy Initialization with Memoization
- `embedding` property lazy-loaded on first access
- Cached for subsequent accesses
- Automatic generation via `vectorizable_content`

### Type Safety
- Strict type validation in constructors
- TypeError for wrong types
- ArgumentError for invalid values
- No defensive nil checks

### Single Responsibility
- `Embedding`: Holds vector + similarity calculation
- `BaseMemory`: Common memory behavior + embedding generation
- Specific memories: Domain logic + vectorizable content
- `VectorizationService`: Vector generation and similarity search

## Benefits

### 1. Semantic Understanding
- Finds relevant context based on meaning, not keywords
- Better than exact string matching
- Understands synonyms and related concepts

### 2. Automatic Relevance
- No manual context selection needed
- Threshold-based filtering (configurable)
- Sorted by similarity score

### 3. Type Safety
- Domain objects enforce structure
- No hash key typos
- Clear APIs

### 4. Performance
- Lazy embedding generation
- Memoization prevents redundant API calls
- Efficient cosine similarity calculation

### 5. Testability
- Pure domain objects easy to test
- No mocks needed for similarity calculations
- Clear input/output contracts

## Configuration

### Embedding Model
- **Model**: text-embedding-3-small (OpenAI-compatible)
- **Dimension**: 1536
- **Port**: 52004 (separate from LLM)
- **Max tokens**: 8191 input tokens

### Similarity Thresholds
- **Default**: 0.70 (70% similar)
- **High relevance**: 0.80+
- **Medium relevance**: 0.60-0.80
- **Low relevance**: below 0.60 (filtered out)

### Retry Configuration
- Uses same retry logic as GenericLlmClient
- Configurable attempts and delay
- Resilient to temporary failures

## Migration Path

1. **Phase 1**: Add new domain objects alongside existing hash storage
2. **Phase 2**: Update record methods to create both (dual write)
3. **Phase 3**: Add vector query methods alongside old methods
4. **Phase 4**: Migrate call sites to new API
5. **Phase 5**: Remove old hash-based storage
6. **Phase 6**: Clean up deprecated methods

## Future Enhancements

- **Batch embedding**: Generate multiple embeddings in one API call
- **Embedding cache**: Store embeddings in database for reuse
- **Custom models**: Support different embedding models per use case
- **Hybrid search**: Combine vector + keyword search
- **Clustering**: Group similar memories automatically
- **Visualization**: Plot memory relationships in 2D/3D

## References

- OOP Patterns: Lesson 20 (Required Parameters)
- OOP Patterns: Lesson 21 (Singleton Pattern)
- Vector similarity: Cosine distance
- OpenAI Embeddings API: text-embedding-3-small

