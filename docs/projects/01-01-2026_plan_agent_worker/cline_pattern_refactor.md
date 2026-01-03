# Daedalus Refactor: Following Cline Pattern

## Problem

Current implementation has Daedalus using a separate `CodebaseAnalysisWorkflow` before plan generation. This doesn't match Cline's pattern where codebase exploration happens **during** planning, not before.

## Cline's Approach (from https://github.com/cline/cline)

According to Cline's documentation:

> "Cline starts by analyzing your file structure & source code ASTs, running regex searches, and reading relevant files to get up to speed in existing projects. By carefully managing what information is added to context, Cline can provide valuable assistance even for large, complex projects without overwhelming the context window."

> "Once Cline has the information he needs, he can: Create and edit files..."

**Key insight**: Cline explores AS NEEDED during task execution, not in a separate analysis phase.

## Required Changes

### 1. DaedalusWorker Simplification

**REMOVE**: Separate `run_analysis` phase and `CodebaseAnalysisWorkflow`
**KEEP**: Direct tool registration (FileTreeTool, GrepTool, ReadFileTool)

```ruby
class DaedalusWorker < BaseWorker
  # Register tools for direct use (Cline pattern)
  register_tool FileTreeTool
  register_tool GrepTool  
  register_tool ReadFileTool
  
  # Simplified flow
  def execute
    initialize_worker
    run_planning  # Planning explores codebase as needed
    write_output
    build_result
  end
end
```

### 2. PlanGenerationWorkflow Enhancement

The workflow should:
1. Accept `path` parameter (codebase root)
2. Have access to tools (FileTree, Grep, ReadFile)
3. Include codebase exploration context in the LLM prompt
4. Let LLM decide what files to explore based on goal

**New signature**:
```ruby
def initialize(goal:, path:, owner_id:, parent_memory: nil, context: nil)
  @goal = goal
  @path = path  # For codebase exploration
  @context = context
end
```

### 3. PlanGenerationPrompt Update

The prompt should:
1. Describe available tools (file_tree, grep, read_file)
2. Instruct LLM to explore codebase as needed
3. Guide LLM to generate plan based on discoveries
4. Include path context

```ruby
# System prompt should explain:
# - You have access to file_tree, grep, and read_file tools
# - Explore the codebase at #{path} to understand structure
# - Generate a detailed plan with milestones and steps
# - Each step should reference specific files when relevant
```

### 4. Tool Integration Pattern

Following OOP principles:
- Tools are registered at worker level
- Workflow accesses tools through worker
- Each tool use is recorded in memory
- Tool results guide plan generation

## Benefits

1. **Matches Cline**: Exploration during planning, not before
2. **More Flexible**: LLM decides what to explore based on goal
3. **Simpler**: One workflow instead of two
4. **Better Context**: Exploration results directly inform planning
5. **OOP Compliant**: Tools as first-class objects, not hash results

## Implementation Status

- [ ] Update DaedalusWorker (remove analysis phase)
- [ ] Update PlanGenerationWorkflow (add path, tool access)
- [ ] Update PlanGenerationPrompt (add tool usage instructions)
- [ ] Update tests (remove analysis workflow tests)
- [ ] Update E2E tests (expect better codebase exploration)
- [ ] Remove CodebaseAnalysisWorkflow dependency
- [ ] Update documentation

## Testing Strategy

Use `example_codebase` fixture for E2E tests to verify:
- Real codebase exploration during planning
- Multiple files analyzed
- Plan references specific files
- Milestones reflect actual codebase structure

Expected result with example_codebase:
- Should find Calculator, MathService, NotificationService
- Should generate plan that references these files
- Should create milestones based on service structure
- Should be slower (~30-60s) due to real exploration


