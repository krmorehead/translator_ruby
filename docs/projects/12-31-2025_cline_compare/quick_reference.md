# Quick Reference: Cline vs translator_ruby

**Last Updated:** December 31, 2025

---

## Side-by-Side Comparison

| Feature | Cline | translator_ruby | Winner |
|---------|-------|-----------------|--------|
| **Deployment** | IDE Extension | Rails Server | Tie (different models) |
| **Language** | TypeScript/React | Ruby/Rails | Preference-dependent |
| **Execution** | Client-side | Server-side | Context-dependent |
| **State Management** | Implicit (snapshots) | Explicit (state machines) | **translator_ruby** |
| **Memory** | Ephemeral (MCP) | Persistent (JSON stores) | **translator_ruby** |
| **UX** | Visual diffs, checkpoints | Basic JSON responses | **Cline** |
| **Safety** | Rollback + approval gates | Validation + auditing | **Cline** |
| **Workflows** | Plan → Act (linear) | Multi-workflow orchestration | **translator_ruby** |
| **Tools** | TypeScript functions | OOP classes | **translator_ruby** |
| **IDE Integration** | Native (VS Code API) | None (frontend only) | **Cline** |
| **Research** | Surface-level | Deep + iterative | **translator_ruby** |
| **Session Memory** | None | Full persistence | **translator_ruby** |
| **Concurrency** | Single-threaded | Multi-model (3-4 streams) | **translator_ruby** |
| **Setup Complexity** | Install extension | Rails + Postgres + config | **Cline** |
| **Transparency** | Real-time UI feedback | Memory logs | **Cline** |
| **Learning** | None (stateless) | Cross-session | **translator_ruby** |

**Overall:** Different strengths for different use cases

---

## Key Architectural Patterns

### Cline's Patterns

```typescript
// 1. Plan-Act Workflow
const workflow = {
  plan: async () => {
    const plan = await agent.analyzeProblem()
    await user.approve(plan)
    return plan
  },
  act: async (plan) => {
    for (const step of plan) {
      await createCheckpoint()
      await user.approve(step)
      await executeStep(step)
    }
  }
}

// 2. Checkpoint System
class CheckpointManager {
  createCheckpoint(): string
  rollback(checkpointId: string): void
  diff(checkpointId: string): Diff
}

// 3. MCP Integration
interface ContextProvider {
  query(resource: string): Promise<Data>
  connect(api: string): Connection
}
```

### translator_ruby's Patterns

```ruby
# 1. Worker-Workflow Orchestration
class ProjectPlannerWorker < BaseWorker
  register_workflow ResearchWorkflow
  register_workflow ProjectPlanningWorkflow
  
  def execute
    trigger(:start)
    perform_research      # Workflow 1
    trigger(:researched)
    generate_plan         # Workflow 2
    trigger(:planned)
    write_output_files
    trigger(:finish)
  end
end

# 2. State Machine
class BaseWorkflow
  include StateMachine
  
  initial_state :pending
  state :running
  state :complete
  state :failed
  
  transition from: :pending, to: :running, on: :start
  # Invalid transitions raise errors
end

# 3. Hierarchical Memory
class WorkflowMemoryStore
  attr_reader :parent_memory
  
  def query_parent(*sections)
    parent_memory.get_section(section)
  end
  
  def merge_to_parent(*sections)
    # Child findings → parent memory
  end
end

# 4. OOP Tools
class BaseTool
  def self.schema
    { type: "function", function: { ... } }
  end
  
  def execute(**args)
    { success: bool, result: string, error: string }
  end
end
```

---

## Architecture Diagrams

### Cline Architecture

```
┌─────────────────────────────────────┐
│         VS Code / JetBrains         │
│  (User's Local Development Env)     │
└─────────────┬───────────────────────┘
              │
    ┌─────────▼──────────┐
    │  Extension Layer   │
    │   (src/extension)  │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │   Webview UI       │
    │  (React/TypeScript)│
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │    Agent Core      │
    │  (Plan/Act modes)  │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │   MCP + Tools      │
    │ (Terminal/Browser) │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │    LLM APIs        │
    │ (Claude/GPT/etc)   │
    └────────────────────┘
```

### translator_ruby Architecture

```
┌─────────────────────────────────────┐
│       Frontend (React/Vite)         │
│     (User's Browser)                │
└─────────────┬───────────────────────┘
              │ REST/SSE
    ┌─────────▼──────────┐
    │   Rails Controllers│
    │   (API Endpoints)  │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │      Workers       │
    │  (BaseWorker →     │
    │   ProjectPlanner,  │
    │   CodebaseResearch)│
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │     Workflows      │
    │  (BaseWorkflow →   │
    │   Research,        │
    │   Planning)        │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │   Services         │
    │ (GenericLLMClient, │
    │  ToolCallService)  │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │      Tools         │
    │  (BaseTool →       │
    │   ReadFile, Grep,  │
    │   Bash, etc)       │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │   Memory Stores    │
    │  (WorkflowMemory,  │
    │   ResearchMemory)  │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │  LLM Providers     │
    │ (OpenAI/Anthropic/ │
    │  Bedrock)          │
    └────────────────────┘
```

---

## Code Examples

### User Approval Flow

**Cline:**
```typescript
// User approves each step
for (const change of fileChanges) {
  const approved = await vscode.window.showInformationMessage(
    `Apply changes to ${change.file}?`,
    'Yes', 'No', 'View Diff'
  )
  
  if (approved === 'View Diff') {
    await showDiff(change)
  }
  
  if (approved === 'Yes') {
    await applyChange(change)
    await createCheckpoint()
  }
}
```

**translator_ruby:**
```ruby
# Agent executes autonomously, logs decisions
def write_output_files
  record_decision(
    decision: "Writing output files",
    rationale: "Persisting project plan to filesystem",
    context: { project_name: project_name }
  )
  
  output_service.write(
    file_references_content: @planning_result.file_references_content,
    project_plan_content: @planning_result.project_plan_content
  )
  
  # User reviews via memory logs or file changes
end
```

### Memory Storage

**Cline:**
```typescript
// Ephemeral - context from MCP
const context = await mcp.query({
  resource: 'database/schema',
  filter: 'users_table'
})

// No persistence between sessions
```

**translator_ruby:**
```ruby
# Persistent - survives restarts
@memory_store.record_decision(
  decision: "Starting codebase research",
  rationale: "Gathering information about the codebase for planning",
  context: { goal: goal, max_depth: @max_research_depth }
)

# Saved to JSON file immediately
# Can be queried by child workflows
workflow_memory.query_parent(:research_goal, :findings)
```

### State Transitions

**Cline:**
```typescript
// Implicit state through mode
let mode: 'plan' | 'act' = 'plan'

if (planningComplete) {
  mode = 'act'
  await executeActMode()
}

// No enforcement of invalid transitions
```

**translator_ruby:**
```ruby
# Explicit state machine
class ProjectPlannerWorker < BaseWorker
  state :pending
  state :researching
  state :planning
  state :writing
  state :complete
  
  transition from: :researching, to: :planning, on: :researched
  
  # Invalid transitions raise StateTransitionError
  trigger(:researched)  # Only valid if current_state == :researching
end
```

---

## When to Use Each

### Use Cline When:
- ✅ Quick code edits and refactors
- ✅ Interactive debugging sessions
- ✅ Learning how AI agents think
- ✅ You want immediate user control
- ✅ Single-session tasks
- ✅ IDE-native workflows
- ✅ Visual code review is critical

### Use translator_ruby When:
- ✅ Multi-day research projects
- ✅ Complex workflow orchestration
- ✅ Memory across sessions is needed
- ✅ Autonomous operation is acceptable
- ✅ Deep codebase analysis required
- ✅ Multiple models running in parallel
- ✅ Persistent decision auditing
- ✅ Long-running background tasks

### Future: Hybrid System
- Local IDE extension (Cline-style UX)
- Remote memory service (translator_ruby-style persistence)
- Best of both worlds

---

## Migration Path (translator_ruby)

### Phase 1: Safety & Trust ✅ Do First
```
[x] Git checkpoint system
[x] Visual diff preview
[x] Error recovery UI
```

### Phase 2: Transparency & Control
```
[ ] Explicit planning phase
[ ] State machine visualization  
[ ] Live progress tracking
```

### Phase 3: Advanced Features
```
[ ] MCP-style integrations
[ ] Browser automation
[ ] Tool composition
[ ] Memory enhancements
```

---

## Key Metrics Comparison

| Metric | Cline | translator_ruby |
|--------|-------|-----------------|
| **Time to First Result** | Seconds | Minutes |
| **Memory Usage** | None (ephemeral) | Full (persistent) |
| **User Approval Required** | Every step | None (audit only) |
| **Max Task Duration** | Hours (user present) | Days (autonomous) |
| **Setup Time** | 1 minute (install) | 30+ min (Rails setup) |
| **Learning Curve** | Low | Medium-High |
| **Code Coverage (tests)** | ? | 100+ tests |
| **State Complexity** | Low | High (state machines) |
| **Tool Count** | ~10 | ~15 |
| **Workflow Count** | 1 (Plan-Act) | 6+ specialized |

---

## Rapid Fire: What's Better Where?

| Aspect | Better Implementation | Why |
|--------|----------------------|-----|
| UX | Cline | Visual diffs, checkpoints, real-time |
| Memory | translator_ruby | Persistent, hierarchical, queryable |
| Safety | Cline | User approval + rollback |
| Validation | translator_ruby | OOP contracts, type checking |
| IDE Integration | Cline | Native VS Code/JetBrains |
| Workflows | translator_ruby | Multi-phase, composable |
| State Management | translator_ruby | Explicit state machines |
| Transparency | Cline | Real-time UI feedback |
| Research | translator_ruby | Deep, iterative, memory-backed |
| Setup | Cline | 1-minute install |
| Testing | translator_ruby | Comprehensive test suite |
| Concurrency | translator_ruby | 3-4 parallel models |
| Learning | translator_ruby | Cross-session memory |
| Control | Cline | User approval every step |

---

## Bottom Line

**Cline:** Amazing UX, developer control, IDE native → **Short-term productivity**  
**translator_ruby:** Deep capability, persistent memory, orchestration → **Long-term automation**

**Winner:** Depends on use case  
**Best Future:** Combine both approaches

---

## Further Reading

- Full comparison: `architecture_comparison.md`
- Action items: `key_takeaways.md`
- Cline GitHub: https://github.com/cline/cline
- Our OOP patterns: `docs/references/oop-patterns.md`

