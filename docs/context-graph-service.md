# Context Graph Service - Pseudo Graph Database

## Overview

The `ContextGraphService` is a **pseudo graph database** that automatically tracks all memory stores and workflows in the application. It provides a unified API for querying context across the entire application using graph traversal with distance-based degradation.

## Auto-Registry System

### How It Works

When memory stores or workflows are instantiated, they **automatically register themselves** with the `ContextGraphService`. No manual registration is required.

```ruby
# Creating a memory store automatically registers it
store = MemoryStore.new(path: "memory.json")
# => Automatically creates a Graph::WorkerNode and registers it

# Creating a workflow automatically registers it AND creates parent edges
workflow = WorkflowMemoryStore.new(
  workflow_id: SecureRandom.uuid,
  workflow_name: "my_workflow",
  path: "workflow.json",
  parent_memory: store
)
# => Automatically creates a Graph::WorkflowNode
# => Automatically creates a ParentChildEdge to parent store
```

### Registration Flow

1. **MemoryStore/ResearchMemoryStore**:
   - Calls `ContextGraphService.instance.register_memory_store(self)` in `initialize`
   - Service creates `Graph::WorkerNode` wrapping the store
   - Node is indexed by store's `id`

2. **WorkflowMemoryStore**:
   - Calls `ContextGraphService.instance.register_workflow_memory_store(self)` in `initialize`
   - Service creates `Graph::WorkflowNode` wrapping the workflow
   - Node is indexed by workflow's `workflow_id`
   - Service **automatically creates `ParentChildEdge`** if parent memory exists

## Graph Structure

### Nodes

- **WorkerNode**: Wraps `MemoryStore` or `ResearchMemoryStore`
  - ID: `store.id` (UUID)
  - Delegates context queries to the memory store

- **WorkflowNode**: Wraps `WorkflowMemoryStore`
  - ID: `workflow.workflow_id` (UUID)
  - Delegates context queries to workflow memories

### Edges

- **ParentChildEdge**: Connects workflow to parent memory
  - `from_node_id`: workflow's ID
  - `to_node_id`: parent's ID (supports both MemoryStore and WorkflowMemoryStore parents)
  - Automatically created when workflow has `parent_memory`

## Querying the Graph

### Basic Query

```ruby
service = ContextGraphService.instance

results = service.query(
  workflow_id: "my-workflow-id",
  context_type: :decision,
  query_vector: "database choice rationale",
  threshold: 0.7,
  limit: 5
)

# Returns: [
#   {
#     memory: <Decision object>,
#     similarity: 0.85,
#     final_score: 0.82,  # similarity * degradation
#     distance: 1,        # graph hops from start
#     source: "worker:abc123:decisions",
#     path: ["workflow-id", "parent-id"]
#   }
# ]
```

### Query Parameters

- `workflow_id`: Starting point for graph traversal
- `context_type`: Type of context (`:decision`, `:goal`, `:research_goal`, etc.)
- `query_vector`: String or Embedding to search with
- `threshold`: Minimum similarity score (0.0-1.0), defaults to 0.7
- `edge_types`: Optional array of edge types to filter (nil = all edges)
- `limit`: Maximum results to return (nil = all matching)

### Distance-Based Degradation

The service applies **automatic degradation** based on graph distance:

```ruby
degradation = 1.0 / (1.0 + distance * 0.3)

# Examples:
# distance 0: degradation = 1.00 (no penalty)
# distance 1: degradation = 0.77 (23% penalty)
# distance 2: degradation = 0.625 (37.5% penalty)
# distance 3: degradation = 0.526 (47.4% penalty)
```

**Final score** = similarity × degradation

### Early Termination

The service calculates the maximum distance where even a perfect match (similarity = 1.0) would meet the threshold, and stops traversal beyond that point.

## Context Type Registry

The `Graph::ContextTypeRegistry` maps abstract context types to concrete memory sections:

```ruby
Graph::ContextTypeRegistry.registered_types
# => [:decision, :state_transition, :goal, :research_goal, ...]

Graph::ContextTypeRegistry.sections_for(:decision)
# => [:decisions]

Graph::ContextTypeRegistry.sections_for(:goal)
# => [:current_goal, :quests]
```

## Example: Complete Workflow

```ruby
# 1. Create worker memory
worker_memory = ResearchMemoryStore.new(path: "worker.json")
# => Auto-registered as WorkerNode

# 2. Add context to worker
worker_memory.update_section(
  name: :research_goal,
  content: { text: "Understand authentication flow" }
)

# 3. Create workflow with parent
workflow = WorkflowMemoryStore.new(
  workflow_id: SecureRandom.uuid,
  workflow_name: "research_workflow",
  path: "workflow.json",
  parent_memory: worker_memory
)
# => Auto-registered as WorkflowNode
# => Auto-creates ParentChildEdge to worker_memory

# 4. Add decisions to workflow
workflow.record_decision(
  decision: "Focus on OAuth implementation",
  rationale: "Most complex authentication mechanism",
  context: {}
)

# 5. Query from workflow perspective
service = ContextGraphService.instance
results = service.query(
  workflow_id: workflow.workflow_id,
  context_type: :decision,
  query_vector: "authentication strategy",
  threshold: 0.6
)

# Returns decisions from:
# - This workflow (distance 0)
# - Parent worker memory (distance 1, with degradation)
```

## Integration Test Example

See `test/integration/context_graph_integration_test.rb` for comprehensive examples including:

- Auto-registration verification
- Parent-child edge creation
- Multi-level hierarchies (grandparent → parent → child)
- Querying across the graph

## Key Benefits

1. **Zero Manual Registration**: Just create objects, they register themselves
2. **Automatic Relationships**: Edges created based on `parent_memory`
3. **Unified Query API**: Single method to search across all context
4. **Smart Degradation**: Distance-based relevance scoring
5. **Early Termination**: Optimized graph traversal
6. **Thread-Safe**: Mutex-protected shared state
7. **Type-Safe**: Strict validation on all nodes and edges

## Architecture

```
ContextGraphService (Singleton)
├── @nodes: { id => Graph::Node }
│   ├── WorkerNode (wraps MemoryStore/ResearchMemoryStore)
│   └── WorkflowNode (wraps WorkflowMemoryStore)
├── @edges: [Graph::Edge]
│   └── ParentChildEdge (workflow → parent)
└── Query Methods
    ├── Dijkstra's shortest paths
    ├── Distance-based degradation
    ├── Vector similarity search
    └── Early termination optimization
```

## Testing

Run the integration tests:

```bash
bundle exec rails test test/integration/context_graph_integration_test.rb
```

Run all graph tests:

```bash
bundle exec rails test test/models/graph/ test/services/context_graph_service_test.rb
```


