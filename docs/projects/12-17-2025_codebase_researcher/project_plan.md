# Project Plan: Codebase Researcher Worker

## Overview

Create a new Worker abstraction layer and implement a CodebaseResearcher worker that can investigate arbitrary codebases given a research topic. The researcher decomposes topics into sub-questions, discovers relevant files, analyzes code, and synthesizes findings into structured documentation.

## Goals

- Introduce a Worker abstraction that orchestrates multiple workflows
- Build a CodebaseResearcher worker with iterative, decomposed research capabilities
- Extend the memory system to support chained context across research iterations
- Create specialized tools for file discovery and code analysis
- Output research findings to configurable directory (`.agents/references/` by default)
- Validate with a fixture codebase in tests

---

## Milestone 1 - Worker Infrastructure

Establish the Worker abstraction and basic CodebaseResearcher structure.

### 1.1 - Create BaseWorker Class

**Intent**: Create an abstract base class for Workers that can orchestrate multiple workflows. Workers manage the lifecycle of research sessions, maintain shared context, and coordinate workflow execution order. Each worker instance gets a unique owner_id for state isolation.

**Details**:
- Create `app/workers/base_worker.rb`
- **Owner ID for state isolation**:
  - Each worker instance generates a unique `owner_id` (UUID)
  - Owner ID is passed to all memory stores and workflows
  - Enables parallel workers without state collision
- Workers hold a collection of registered workflows
- Workers maintain a shared memory context across workflows (scoped by owner_id)
- Provide `register_workflow(workflow_class)` class method
- Provide `execute(goal:, path:, **options)` instance method
- Track worker status: pending, running, complete, failed
- Store results from each workflow execution
- Support a configurable output path (ENV["RESEARCH_OUTPUT_PATH"] or default `.agents/references/`)
- Support a configurable state path (ENV["AGENT_STATE_PATH"] or default `.agents/state/{owner_id}/`)
- Validate path exists and is readable before starting

**Tests**:
- Test worker initialization with valid path
- Test worker generates unique owner_id
- Test workflow registration
- Test status transitions
- Test execute raises NotImplementedError in base class
- Test path validation (rejects non-existent paths)
- Test parallel workers have isolated state (different owner_ids)

---

### 1.2 - Create CodebaseResearcher Worker

**Intent**: Implement the first concrete Worker that orchestrates codebase research. This worker will eventually coordinate multiple research workflows but starts with a simple structure.

**Details**:
- Create `app/workers/codebase_researcher.rb`
- Inherits from BaseWorker
- Accepts `goal` (research topic string) and `path` (codebase root)
- Creates a ResearchMemoryStore for the research session
- Defines execution order for workflows (will be populated in later milestones)
- Collects findings from each workflow into a unified result

**Tests**:
- Test initialization with goal and path
- Test creates memory store
- Test execute returns structured result (uses real LLM calls, no mocking)
- Test handles LLM errors gracefully

---

### 1.3 - Create Example Fixture Codebase

**Intent**: Create a small but realistic Ruby codebase fixture that can be used for testing the researcher. This fixture should have enough complexity to validate file discovery, dependency analysis, and code understanding.

**Details**:
- Create `test/fixtures/example_codebase/` directory structure
- Include `lib/calculator.rb` - a simple Calculator class with add, subtract, multiply, divide
- Include `lib/formatter.rb` - a Formatter class that depends on Calculator for formatting numbers
- Include `app/services/math_service.rb` - a service that uses both Calculator and Formatter
- Include `README.md` - basic documentation explaining the codebase
- Include `Gemfile` - minimal dependencies
- Structure should be realistic but small (~5-10 files)

**Tests**:
- Test fixture files exist
- Test fixture is valid Ruby (can be parsed)
- Test dependencies are traceable (MathService → Formatter → Calculator)

---

## Milestone 2 - Memory System Refactor

Refactor the existing memory system to support OOP hierarchy before adding research memories.

### 2.1 - Create GoalBasedMemory Base Class

**Intent**: Create a shared abstract base for goal/quest-like memories. Both existing D&D memories (CurrentGoalMemory, MainQuestMemory, QuestsMemory) and new research memories (ResearchGoalMemory, SubQuestionsMemory) share common behavior around tracking objectives and their completion states.

**Details**:
- Create `app/models/memories/goal_based_memory.rb`
- Inherits from BaseMemory
- Provides common structure for goal entries: text, priority, status (pending/active/complete)
- Provides `active_goals` class method to filter active entries
- Provides `complete_goal(id)` class method to mark goals complete
- Default weight: 0.9 (goals are high priority for context)

**Tests**:
- Test goal entry structure includes status
- Test active_goals filters correctly
- Test complete_goal updates status

---

### 2.2 - Refactor Existing D&D Goal Memories

**Intent**: Update existing goal-related memories to inherit from GoalBasedMemory, establishing the OOP hierarchy before adding research memories.

**Details**:
- Refactor `app/models/memories/current_goal_memory.rb` to inherit from GoalBasedMemory
- Refactor `app/models/memories/main_quest_memory.rb` to inherit from GoalBasedMemory
- Refactor `app/models/memories/quests_memory.rb` to inherit from GoalBasedMemory
- Ensure backward compatibility - existing functionality must not break
- Update registry if needed

**Tests**:
- Test CurrentGoalMemory still works after refactor
- Test MainQuestMemory still works after refactor
- Test QuestsMemory still works after refactor
- Test all three inherit goal behavior (active_goals, complete_goal)
- Run existing D&D memory tests to verify no regressions

---

## Milestone 3 - Research Memory System

Create research-specific memory classes using the refactored hierarchy.

### 3.1 - Create ResearchMemoryStore

**Intent**: Create a specialized memory store for research sessions. Builds on MemoryStore but includes research-specific sections, owner-based isolation, and context chaining between iterations.

**Details**:
- Create `app/models/research_memory_store.rb`
- Create `app/models/research_memory_kinds.rb` with section constants
- Inherits behavior from MemoryStore pattern
- **Owner ID support**:
  - Required `owner_id` parameter on initialization
  - File path defaults to `.agents/state/{owner_id}/research_memory.json`
  - Provides `self.find_by_owner(owner_id)` class method to load existing store
  - Provides `self.list_owners` class method to enumerate existing sessions
- Sections: research_goal, sub_questions, discovered_files, findings, context_chain, iteration_log
- Supports `push_context(context)` for chaining reasoning across iterations
- Supports `pop_context` to retrieve and consume chained context
- Supports `current_iteration` tracking
- Provides `summarize_findings` method for compression

**Tests**:
- Test creates with default sections
- Test requires owner_id
- Test find_by_owner loads existing store
- Test list_owners returns all session IDs
- Test push_context/pop_context
- Test iteration tracking
- Test summarize_findings produces summary
- Test persistence to file
- Test parallel stores with different owner_ids are isolated

---

### 3.2 - Create Research Memory Classes

**Intent**: Create individual memory classes for each research memory section. Goal-related memories extend GoalBasedMemory, others extend BaseResearchMemory.

**Details**:
- Create `app/models/memories/research/` directory
- Create `base_research_memory.rb` - base class for research-specific memories (inherits BaseMemory)
- Create `research_goal_memory.rb` - stores main research objective (inherits GoalBasedMemory, weight: 1.0)
- Create `sub_questions_memory.rb` - stores decomposed questions (inherits GoalBasedMemory, weight: 0.9)
- Create `discovered_files_memory.rb` - stores file paths and relevance (inherits BaseResearchMemory, weight: 0.7)
- Create `findings_memory.rb` - stores analysis findings (inherits BaseResearchMemory, weight: 0.8)
- Create `registry.rb` - registers all research memory classes
- Each class implements section_name, weight, and summarize

**Tests**:
- Test ResearchGoalMemory inherits goal behavior
- Test SubQuestionsMemory inherits goal behavior
- Test each memory class has correct section_name and weight
- Test summarize produces meaningful output
- Test registry contains all research memories

---

### 3.3 - Create ContextChainMemory

**Intent**: Create a specialized memory for maintaining reasoning chains across research iterations. This enables the researcher to build on previous understanding without losing context.

**Details**:
- Create `app/models/memories/research/context_chain_memory.rb`
- Inherits from BaseResearchMemory
- Stores ordered list of context entries
- Each entry has: iteration number, sub_question, key insights, timestamp
- Provides `chain_for(sub_question)` to get relevant context for a question
- Supports compression when chain exceeds token limit
- Weight: 0.95 (high priority for context preservation)

**Tests**:
- Test stores context entries in order
- Test retrieves chain for specific sub-question
- Test compression when limit exceeded
- Test timestamp ordering

---

## Milestone 4 - Research Tools

Create specialized tools for codebase investigation.

### 4.1 - Create FileTreeTool

**Intent**: Create a tool that lists directory structure recursively. Essential for discovering what files exist in a codebase.

**Details**:
- Create `app/tools/file_tree_tool.rb`
- Parameters: path (directory), max_depth (default: 10), extensions (optional filter)
- Returns structured tree with file paths, types, and sizes
- Respects common ignore patterns (.git, node_modules, vendor/bundle)
- Supports configurable ignore patterns
- Formats output as indented tree string and structured array
- Register with ToolCallService

**Tests**:
- Test lists directory contents
- Test respects max_depth
- Test filters by extension
- Test ignores .git directory
- Test handles non-existent path

---

### 4.2 - Create GrepTool

**Intent**: Create a tool that searches file contents for patterns. Enables finding files that mention specific terms, classes, or concepts.

**Details**:
- Create `app/tools/grep_tool.rb`
- Parameters: pattern (regex string), path (directory), extensions (optional), max_results (default: 100)
- Returns matching lines with file path, line number, and context
- Supports case-insensitive matching
- Supports whole-word matching
- Uses Ruby's Dir.glob and File.readlines for portability
- Register with ToolCallService

**Tests**:
- Test finds pattern in files
- Test returns line numbers
- Test respects max_results
- Test handles regex patterns
- Test case-insensitive option

---

### 4.3 - Create DependencyGraphTool

**Intent**: Create a language-flexible tool that analyzes file dependencies across different programming languages. Uses file extensions to determine import patterns, with LLM fallback for unknown languages.

**Details**:
- Create `app/tools/dependency_graph_tool.rb`
- Parameters: path (file or directory), depth (how deep to follow deps), language_hint (optional override)
- **Language detection by file extension** (hardcoded patterns):
  - `.rb` → Ruby:
    - `require` / `require_relative` - file loading
    - `include ModuleName` - mixin inclusion
    - `extend ModuleName` - singleton method extension
    - `prepend ModuleName` - method chain prepending
    - `class Child < Parent` - class inheritance
    - `include Concerns::Name` - Rails concerns
  - `.py` → Python:
    - `import module`
    - `from module import name`
    - `from module import *`
  - `.js/.ts/.jsx/.tsx` → JavaScript/TypeScript:
    - `import { x } from 'module'`
    - `import x from 'module'`
    - `import * as x from 'module'`
    - `const x = require('module')`
    - `export { x } from 'module'` (re-exports)
  - `.go` → Go:
    - `import "package"`
    - `import ( "pkg1" "pkg2" )` (grouped)
  - `.java` → Java:
    - `import package.Class`
    - `import package.*`
    - `extends ClassName`
    - `implements InterfaceName`
  - `.rs` → Rust:
    - `use crate::module`
    - `use module::item`
    - `mod module_name`
    - `pub use` (re-exports)
- **Unknown language fallback**: When extension is unrecognized:
  - Use LLM (via simple prompt) to identify import patterns from file sample
  - Cache the detected pattern for the session
- **No imports case**: Gracefully handle files with no import statements
- Returns graph structure: nodes (files) and edges (dependencies)
- Supports visualization-friendly output format
- Register with ToolCallService

**Tests** (LLM fallback tests use real LLM calls, no mocking):
- Test Ruby require/require_relative extraction
- Test Python import extraction
- Test JavaScript/TypeScript import extraction
- Test unknown extension triggers LLM fallback (real LLM call)
- Test file with no imports returns empty edges
- Test respects depth limit
- Test handles circular dependencies
- Test mixed-language codebase

---

## Milestone 5 - Research Prompts

Create LLM prompts for each research operation.

### 5.1 - Create TopicDecompositionPrompt

**Intent**: Create a prompt that breaks research topics into focused sub-questions with base case detection. Guides the LLM to produce actionable, specific questions and identify when questions are "leaf" level (no further decomposition needed).

**Details**:
- Create `app/prompts/research/topic_decomposition_prompt.rb`
- Inherits from BasePrompt
- System prompt explains: codebase research context, goal of decomposition
- **Base case detection**: For each sub-question, LLM evaluates:
  - `is_leaf`: boolean - true if question needs no further decomposition
  - Leaf criteria in prompt:
    - Answerable by examining 1-3 files
    - Specific enough to have a concrete, verifiable answer
    - Doesn't require further context-setting to investigate
- Response schema: array of questions with:
  - `question`: the sub-question text
  - `priority`: ordering importance (1 = highest)
  - `rationale`: why this question matters
  - `is_leaf`: whether this is a leaf (no further decomposition)
  - `parent_id`: optional reference to parent question (for tree building)
- Includes guidance to avoid overly broad questions
- Includes guidance to consider different aspects (architecture, implementation, usage)

**Tests** (all tests use real LLM calls, no mocking):
- Test produces valid JSON response
- Test questions include is_leaf flag
- Test broad questions marked as non-leaf
- Test specific questions marked as leaf
- Test includes rationale for each question
- Test handles vague topics gracefully
- Test handles already-specific topics (returns single leaf)

---

### 5.2 - Create FileRelevancePrompt

**Intent**: Create a prompt that scores file relevance to a research question. Helps filter candidate files to focus on the most relevant ones.

**Details**:
- Create `app/prompts/research/file_relevance_prompt.rb`
- Inherits from BasePrompt
- Input: file path, file preview (first N lines), research question
- Output: relevance score (0-1), reasoning, key terms found
- System prompt explains: scoring criteria, what makes a file relevant
- Batch mode: can score multiple files in one call

**Tests** (all tests use real LLM calls, no mocking):
- Test produces relevance score
- Test includes reasoning
- Test batch mode works
- Test handles binary files gracefully

---

### 5.3 - Create CodeUnderstandingPrompt

**Intent**: Create a prompt that analyzes code content with two output modes: language-agnostic (for research/planning) and language-specific (for debugging/fixes). The mode is determined by analyzing the research goal.

**Details**:
- Create `app/prompts/research/code_understanding_prompt.rb`
- Inherits from BasePrompt
- **Required parameter**: `goal` - the research objective (used to determine mode)
- **Mode selection** (LLM analyzes goal to determine):
  - **Language-specific mode**: When goal involves error investigation, bug fixes, debugging, implementation details
    - Output includes: exact syntax, line numbers, specific method signatures, error traces
  - **Language-agnostic mode**: When goal involves project planning, architecture research, documentation
    - Output includes: conceptual purpose, design patterns, relationships, abstractions
- Input: file content, goal, previous context
- Output structure adapts based on mode:
  - Common: purpose summary, key components, dependencies, patterns
  - Specific mode adds: exact signatures, line references, language idioms
  - Agnostic mode adds: design rationale, architectural role, cross-language concepts
- Supports context chaining (builds on previous analysis)

**Tests** (all tests use real LLM calls, no mocking):
- Test goal "fix the authentication bug" triggers language-specific mode
- Test goal "document the service architecture" triggers language-agnostic mode
- Test produces structured analysis in both modes
- Test identifies dependencies
- Test uses previous context appropriately
- Test handles unknown file types gracefully

---

### 5.4 - Create SynthesisPrompt

**Intent**: Create a prompt that synthesizes findings into unified understanding. Designed to combine multiple parallel analyses and distill results through cross-validation.

**Details**:
- Create `app/prompts/research/synthesis_prompt.rb`
- Inherits from BasePrompt
- **Multi-analysis support**: Accepts array of findings from parallel analysis passes
- **3-pass distillation design**:
  1. Run 3 parallel analysis passes on the same content (handled by workflow)
  2. SynthesisPrompt receives all 3 results
  3. Cross-validates findings: only includes insights that appear in 2+ passes
  4. Flags conflicts where passes disagree
  5. Filters out findings irrelevant to the original topic
- Input: array of findings (from multiple passes), original research goal, sub-questions
- Output structure:
  - `validated_insights`: findings confirmed across multiple passes
  - `conflicts`: areas where passes disagreed (for human review)
  - `filtered_out`: findings deemed irrelevant to topic (with reasoning)
  - `summary`: coherent narrative addressing the goal
  - `detailed_sections`: organized by sub-question
  - `open_questions`: areas needing further investigation
- System prompt explains: cross-validation criteria, relevance filtering, documentation goals

**Tests** (all tests use real LLM calls, no mocking):
- Test combines findings from 3 parallel passes
- Test only includes insights appearing in 2+ passes
- Test identifies and reports conflicts
- Test filters irrelevant findings with reasoning
- Test produces coherent summary addressing original goal
- Test handles single-pass input gracefully (no cross-validation)
- Test handles empty findings array

---

### 5.5 - Create Template-Based Output System

**Intent**: Create a template-based output system that supports multiple output modes: research reports and per-file documentation. Templates are centralized in prompt files for easy modification.

**Details**:
- Create `app/prompts/research/output_templates/` directory for template classes
- Create `base_output_template.rb` - abstract template base class
  - Provides `render(data)` method signature
  - Provides `template_name` identifier
  - Supports variable interpolation
- Create `report_template.rb` - existing research report format
  - Renders synthesis as single document or multi-file report by sub-question
  - Includes: title, summary, table of contents, detailed sections, insights, open questions
- Create `file_doc_template.rb` - per-file documentation template matching `docs/references/` structure:
  ```markdown
  # {file_path}

  ## Summary
  {brief_summary}

  ## Source
  - [View Code]({relative_link_to_file})

  ## External References
  ```mermaid
  graph LR
      {file} --> {dependency_1}
      {file} --> {dependency_2}
  ```

  ## Method Architecture
  ```mermaid
  flowchart TD
      {method_call_diagram}
  ```

  ## Methods
  ### {method_name}
  {method_summary}
  ```
- Create `base_references_template.rb` - directory tree template
  - Matches existing `base_references.md` format in `docs/references/`
  - Tree diagram with short file descriptions
  - Quick navigation links
- Create `synthesis_summary_template.rb` - brief research answer summary
  - Concise answer to original research question
  - Links to relevant per-file docs
  - Generated timestamp and metadata

**Tests**:
- Test each template renders valid markdown
- Test file_doc_template produces mermaid diagrams
- Test base_references_template produces correct tree structure
- Test templates are easily modifiable (centralized location)

---

### 5.6 - Create PerFileDocPrompt

**Intent**: Create a prompt specifically for generating per-file documentation. Extracts method signatures, dependencies, and purposes from code files to populate the file_doc_template.

**Details**:
- Create `app/prompts/research/per_file_doc_prompt.rb`
- Inherits from BasePrompt
- Input: file content, file path, dependencies (from DependencyGraphTool), goal context, sub-questions this file answers
- Output structure:
  - `summary`: brief description of file purpose
  - `external_references`: list of files this file depends on
  - `methods`: array of method details:
    - `name`: method name
    - `purpose`: what the method does
    - `parameters`: list of parameters
    - `returns`: return value description
    - `calls`: other methods this method calls (for method architecture diagram)
  - `relevant_sub_questions`: which decomposed sub-questions this file helps answer
- System prompt explains: documentation goals, AI-friendly formatting, diagram generation guidance

**Tests** (all tests use real LLM calls, no mocking):
- Test produces valid structured output
- Test extracts method list from Ruby file
- Test identifies external dependencies
- Test tags file with relevant sub-questions
- Test handles files with no methods (e.g., configuration files)

---

## Milestone 6 - Research Workflows

Create the workflows that orchestrate research phases. Goal decomposition is separated for reusability.

### 6.1 - Create GoalDecompositionWorkflow

**Intent**: Create a reusable workflow for recursively breaking down goals into actionable sub-goals. This workflow is useful beyond just codebase research - it can be used for project planning, task breakdown, or any hierarchical goal structure.

**Details**:
- Create `app/workflows/goal_decomposition_workflow.rb`
- Inherits from BaseWorkflow
- **Required parameters**: `goal` (the goal to decompose), `owner_id` (for memory isolation)
- **Recursive decomposition with base case**:
  - Uses TopicDecompositionPrompt to break goal into sub-goals
  - For each sub-goal, evaluates if it needs further decomposition
  - **Base case criteria** (stop decomposing when):
    - Goal is answerable by examining 1-3 files
    - Goal is specific enough to have a concrete, verifiable answer
    - Goal doesn't require further context-setting
    - Depth limit reached (configurable, default: 4 levels)
  - LLM determines if each sub-goal is a "leaf" or needs more decomposition
- Stores decomposition tree in SubQuestionsMemory with parent-child relationships
- Returns structured tree of goals with leaf markers
- Supports `max_depth` option to prevent infinite recursion

**Tests** (all tests use real LLM calls, no mocking):
- Test decomposes broad goal into sub-goals
- Test recognizes leaf goals (stops decomposing)
- Test respects max_depth limit
- Test stores parent-child relationships in memory
- Test returns structured tree
- Test handles already-specific goals (returns single leaf)

---

### 6.2 - Create ResearchWorkflow Class

**Intent**: Create the main workflow that orchestrates the full research process. Uses GoalDecompositionWorkflow for recursive goal breakdown, then investigates each leaf goal. Supports two output modes: research report and per-file documentation.

**Details**:
- Create `app/workflows/research_workflow.rb`
- Inherits from BaseWorkflow
- **Required parameters**: `goal`, `owner_id`, `research_path`
- **Optional parameters**: `output_mode` (`:report` or `:documentation`, default: `:report`)
- Adds `research_memory` accessor for ResearchMemoryStore (scoped by owner_id)
- Implements phases based on output mode:

**Common phases (both modes)**:
  1. **Decompose**: Use GoalDecompositionWorkflow to recursively break goal into leaf sub-goals
     - Only leaf goals (base case reached) proceed to discovery
     - Tree structure preserved for synthesis context
  2. **Discover**: For each **leaf** sub-goal:
     - Use FileTreeTool + GrepTool + FileRelevancePrompt to find relevant files
     - Tag each file with which sub-questions it helps answer

**Report mode phases**:
  3. **Analyze**: For each discovered file set:
     - Run **3 parallel passes** using ReadFileTool + DependencyGraphTool + CodeUnderstandingPrompt
     - Each pass analyzes independently to catch different perspectives/errors
     - Collect all 3 results for synthesis cross-validation
  4. **Synthesize**: Use SynthesisPrompt (with 3-pass results) + report_template
     - Cross-validates findings across passes
     - Reconstructs hierarchy from decomposition tree
     - Produces research report document(s)

**Documentation mode phases**:
  3. **Document**: For each relevant file (decomposition determines relevance):
     - Run PerFileDocPrompt to extract summary, methods, dependencies
     - Use FileDocumentationWriter to write per-file .md immediately once validated
     - Tag output with which sub-questions the file answers
  4. **Organize**: After all files processed:
     - Generate base_references.md for each directory containing documented files
     - Generate synthesis_summary.md answering the original research question
     - Only directories with relevant files get base_references.md

**Documentation mode flow**:
```
1. Research Goal: "How does the Calculator work?"
   ↓
2. Decompose into sub-questions:
   - Q1: "What methods does Calculator expose?"
   - Q2: "How does Formatter depend on Calculator?"
   - Q3: "How does MathService compose Calculator and Formatter?"
   ↓
3. Discover files relevant to each sub-question:
   - calculator.rb (relevant to Q1, Q2, Q3)
   - formatter.rb (relevant to Q2, Q3)
   - math_service.rb (relevant to Q3)
   ↓
4. Generate per-file docs ONLY for discovered relevant files
   (each file tagged with which sub-questions it answers)
   ↓
5. Generate base_references.md for directories containing documented files
   ↓
6. Generate synthesis_summary.md answering the original question
```

**Key**: We document files that help answer the research question, not the entire codebase. The sub-question decomposition determines relevance.

- Iterates discover→document for each leaf goal before organizing (documentation mode)
- Chains context between iterations (findings from leaf 1 inform leaf 2 analysis)
- Stores intermediate results in ResearchMemoryStore (scoped by owner_id)
- Returns structured result with findings, output paths, and goal tree

**Tests** (all tests use real LLM calls, no mocking):
- Test initialization with research path, goal, and owner_id
- Test decompose phase produces recursive goal tree
- Test only leaf goals proceed to discovery
- Test discover phase finds relevant files and tags sub-questions
- Test report mode: analyze phase runs 3 parallel passes
- Test report mode: synthesize phase produces report
- Test documentation mode: document phase writes per-file docs
- Test documentation mode: organize phase generates base_references.md
- Test documentation mode: generates synthesis_summary.md
- Test context chains between iterations
- Test handles empty codebase gracefully
- Test respects max_depth parameter

---

## Milestone 7 - Output Service

Create the service that writes research findings to the output directory.

### 7.1 - Create ResearchOutputService with Multiple Output Modes

**Intent**: Create a service that writes formatted research findings to the configured output directory. Supports two output modes: research report and per-file documentation.

**Details**:
- Create `app/services/research_output_service.rb`
- Reads output path from ENV["RESEARCH_OUTPUT_PATH"] or defaults to `.agents/references/`
- Creates output directory if it doesn't exist
- **Output mode parameter**: `:report` (default) or `:documentation`
- **Report mode** (existing behavior):
- Generates filenames from research topic (slugified)
  - Supports single-file and multi-file report by sub-question
- Creates index file when multiple files are generated
- Writes metadata (timestamp, source path, topic) to output
- **Documentation mode** (new):
  - Creates directory structure mirroring researched codebase under `.agents/references/`
  - Only creates directories for files relevant to the research question
  - Generates `base_references.md` for each directory with tree + descriptions
  - Generates per-file `.md` for each analyzed code file (using file_doc_template)
  - Generates `synthesis_summary.md` with research answer at root
  - Each file written individually once analysis confirms value (decomposition strategy)
- Returns list of created file paths

```ruby
# Interface
service = ResearchOutputService.new(research_topic: "How does Calculator work?", base_path: "/path/to/codebase")

# Report mode (default)
service.write(synthesis: synthesis, format: :report)

# Documentation mode
service.write(
  synthesis: synthesis,
  format: :documentation,
  file_analyses: file_analyses  # Array of per-file analysis results from PerFileDocPrompt
)
```

**Tests**:
- Test creates output directory
- Test generates appropriate filename for report mode
- Test writes content to file
- Test creates index for multi-file report output
- Test includes metadata in output
- Test documentation mode creates mirrored directory structure
- Test documentation mode generates base_references.md per directory
- Test documentation mode generates per-file .md files
- Test documentation mode generates synthesis_summary.md

---

### 7.2 - Create FileDocumentationWriter

**Intent**: Create a specialized service for writing per-file documentation. Handles the generation of mermaid diagrams and incremental updates to base_references.md files.

**Details**:
- Create `app/services/file_documentation_writer.rb`
- Uses templates from `app/prompts/research/output_templates/`
- **Methods**:
  - `write_file_doc(file_analysis:, output_dir:)` - writes single file doc using file_doc_template
  - `write_base_references(directory:, files:, output_dir:)` - writes base_references.md for a directory
  - `write_synthesis_summary(synthesis:, output_dir:)` - writes synthesis_summary.md at root
- **Mermaid diagram generation**:
  - `generate_dependency_diagram(file:, dependencies:)` - creates external references graph
  - `generate_method_architecture_diagram(methods:)` - creates method call flowchart
- **Incremental updates**:
  - Tracks which files have been documented
  - Updates base_references.md as files are added
  - Supports partial research runs (can add to existing documentation)
- Returns list of created/updated file paths

**Tests**:
- Test writes individual file doc
- Test generates valid mermaid dependency diagram
- Test generates valid mermaid method architecture diagram
- Test writes base_references.md with tree structure
- Test updates existing base_references.md (incremental)
- Test writes synthesis_summary.md

---

## Milestone 8 - API Endpoint & Integration

Create the API endpoint and complete integration testing.

### 8.1 - Create Research Controller

**Intent**: Create an API endpoint for triggering codebase research. Provides RESTful interface for submitting research tasks with configurable output mode.

**Details**:
- Create `app/controllers/api/v1/research_controller.rb`
- POST `/api/v1/research` endpoint
- Request body:
  ```json
  {
    "goal": "string",
    "path": "string",
    "options": {
      "max_depth": "int",
      "output_mode": "report | documentation"
    }
  }
  ```
- Response:
  ```json
  {
    "status": "string",
    "findings": "array",
    "output_files": "array",
    "output_mode": "report | documentation",
    "errors": "array"
  }
  ```
- Validates goal and path are present
- Validates path exists and is readable
- Validates output_mode is valid (defaults to "report")
- Returns 202 Accepted for async (future) or 200 for sync
- Add route to config/routes.rb

**Tests**:
- Test successful research request with default output_mode (report)
- Test successful research request with output_mode=documentation
- Test validation errors
- Test invalid path rejection
- Test invalid output_mode rejection
- Test response structure includes output_mode
- Test uses real LLM calls (no mocking)

---

### 8.2 - End-to-End Integration Test

**Intent**: Create comprehensive integration tests that exercise the full research flow against the fixture codebase. Validates that all components work together correctly.

**Details**:
- Create `test/integration/codebase_researcher_integration_test.rb`
- Test: Research "How does the calculator work?" on fixture codebase
- Test: Research "What are the dependencies between services?" on fixture
- Test: Verify output files are created in correct location
- Test: Verify output content mentions key classes/methods
- Test: Verify memory store contains expected findings
- Use real LLM calls (no mocking per project rules)
- Test multiple parallel research sessions don't conflict

**Tests** (all tests use real LLM calls, no mocking):
- Integration test for simple topic research
- Integration test for dependency analysis
- Integration test for output file creation
- Integration test for parallel sessions

---

### 8.3 - Cursor Baseline Comparison Test

**Intent**: Create a test that compares our worker's output against Cursor's research output for the same prompt. This establishes a baseline for quality and helps identify areas for improvement. Test both output modes.

**Details**:
- Create `test/fixtures/cursor_baseline/research_prompt.md` with a standard research prompt
  - Prompt should request documentation output mode to test per-file doc generation
- User (Kyle) runs the prompt through Cursor on the example_codebase fixture
- Save Cursor's output as `test/fixtures/cursor_baseline/cursor_output.md`
- Create `test/integration/research_comparison_test.rb`
- Run our worker with the same prompt on the same codebase in **documentation mode**
- Compare outputs on multiple dimensions:
  - **Coverage**: Does the worker mention the same key files/classes?
  - **Structure**: Is the output similarly organized?
  - **Accuracy**: Are the findings factually correct?
  - **Completeness**: Are there gaps in understanding?
  - **Per-file docs**: Are per-file docs generated for each relevant file?
  - **Diagrams**: Are mermaid diagrams valid and useful?
- Output a comparison report (diff-style or structured)
- Test should not fail on differences, but report them for human review

**Expected Output Structure (Documentation Mode)**:
```
.agents/references/
├── synthesis_summary.md           # Brief answer to original research question
├── base_references.md             # Tree of files relevant to this research
└── lib/
│   ├── base_references.md         # Tree for lib directory
│   ├── calculator.md              # Per-file doc (answers Q1, Q2, Q3)
│   └── formatter.md               # Per-file doc (answers Q2, Q3)
└── app/services/
    ├── base_references.md         # Tree for services directory
    └── math_service.md            # Per-file doc (answers Q3)
```

**Tests** (all tests use real LLM calls, no mocking):
- Test worker produces output for baseline prompt in documentation mode
- Test generates per-file docs for relevant files only
- Test generates base_references.md for each directory
- Test generates synthesis_summary.md
- Test comparison report is generated
- Test report identifies coverage differences
- Test report is human-readable

---

## Future Considerations

These items are out of scope for the initial implementation but should be considered for future iterations:

- **Async Processing**: Run research as background jobs for large codebases
- **Incremental Research**: Continue research from previous sessions
- **Cross-Codebase Research**: Research multiple codebases together
- **Worker Collaboration**: Multiple workers collaborating on complex tasks
- **Caching**: Cache file analysis results for faster re-research
- **Interactive Mode**: Allow user to guide research mid-session
- **Output Formats**: Support JSON, YAML, HTML output in addition to markdown
