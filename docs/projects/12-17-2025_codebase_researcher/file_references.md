# File References: Codebase Researcher Worker

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/services/base_workflow.rb` | Abstract workflow base class | Worker will orchestrate workflows |
| `app/services/workflow_orchestrator.rb` | Validates and runs workflows | Reference for Worker design |
| `app/services/dnd_chat_workflow.rb` | Example workflow implementation | Pattern reference |
| `app/models/memory_store.rb` | File-backed memory storage | Will extend for research context |
| `app/models/memory_kinds.rb` | Memory section type constants | Will add research-specific kinds |
| `app/models/memories/base_memory.rb` | Base memory class | Will subclass for research memories |
| `app/models/memories/registry.rb` | Memory class registry | Will register new memory types |
| `app/tools/base_tool.rb` | Abstract tool base class | New tools inherit from this |
| `app/tools/read_file_tool.rb` | File reading tool | Reuse for research |
| `app/prompts/base_prompt.rb` | Abstract prompt base class | New prompts inherit from this |
| `app/services/tool_call_service.rb` | Tool registry and dispatch | Register new research tools |
| `app/services/generic_llm_client.rb` | LLM client wrapper | Used by prompts |
| `config/routes.rb` | API routing | Add researcher endpoint |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| **Worker Infrastructure** | | |
| `app/workers/base_worker.rb` | Abstract worker base class | 1.1 |
| `app/workers/codebase_researcher.rb` | Research worker implementation | 1.2 |
| **Memory System Refactor** | | |
| `app/models/memories/goal_based_memory.rb` | Shared base for goal/quest memories | 2.1 |
| **Research Memory** | | |
| `app/models/research_memory_store.rb` | Research-specific memory store | 3.1 |
| `app/models/research_memory_kinds.rb` | Research memory section types | 3.1 |
| `app/models/memories/research/base_research_memory.rb` | Base for research memories | 3.2 |
| `app/models/memories/research/research_goal_memory.rb` | Current research objective (extends GoalBasedMemory) | 3.2 |
| `app/models/memories/research/sub_questions_memory.rb` | Decomposed sub-questions (extends GoalBasedMemory) | 3.2 |
| `app/models/memories/research/discovered_files_memory.rb` | Files found during research | 3.2 |
| `app/models/memories/research/findings_memory.rb` | Research findings | 3.2 |
| `app/models/memories/research/context_chain_memory.rb` | Chained reasoning context | 3.3 |
| `app/models/memories/research/registry.rb` | Research memory registry | 3.2 |
| **Research Tools** | | |
| `app/tools/file_tree_tool.rb` | Lists directory structure | 4.1 |
| `app/tools/grep_tool.rb` | Search file contents | 4.2 |
| `app/tools/dependency_graph_tool.rb` | Analyzes code dependencies | 4.3 |
| **Research Prompts** | | |
| `app/prompts/research/topic_decomposition_prompt.rb` | Breaks topic into sub-questions | 5.1 |
| `app/prompts/research/file_relevance_prompt.rb` | Scores file relevance | 5.2 |
| `app/prompts/research/code_understanding_prompt.rb` | Analyzes code meaning | 5.3 |
| `app/prompts/research/synthesis_prompt.rb` | Synthesizes findings | 5.4 |
| `app/prompts/research/output_formatting_prompt.rb` | Formats output documents | 5.5 |
| **Research Workflows** | | |
| `app/workflows/goal_decomposition_workflow.rb` | Reusable recursive goal decomposition | 6.1 |
| `app/workflows/research_workflow.rb` | Main research workflow with phases | 6.2 |
| **Output** | | |
| `app/services/research_output_service.rb` | Writes research to output dir | 7.1 |
| **API** | | |
| `app/controllers/api/v1/research_controller.rb` | Research API endpoint | 8.1 |
| **Test Fixtures** | | |
| `test/fixtures/example_codebase/` | Sample codebase for testing | 1.3 |
| `test/fixtures/example_codebase/lib/calculator.rb` | Example Ruby class | 1.3 |
| `test/fixtures/example_codebase/lib/formatter.rb` | Example Ruby class | 1.3 |
| `test/fixtures/example_codebase/app/services/math_service.rb` | Example service | 1.3 |
| `test/fixtures/example_codebase/README.md` | Example docs | 1.3 |
| **Tests** | | |
| `test/workers/base_worker_test.rb` | Base worker tests | 1.1 |
| `test/workers/codebase_researcher_test.rb` | Researcher worker tests | 1.2 |
| `test/models/memories/goal_based_memory_test.rb` | Goal-based memory tests | 2.1 |
| `test/models/research_memory_store_test.rb` | Research memory tests | 3.1 |
| `test/tools/file_tree_tool_test.rb` | File tree tool tests | 4.1 |
| `test/tools/grep_tool_test.rb` | Grep tool tests | 4.2 |
| `test/tools/dependency_graph_tool_test.rb` | Dependency graph tests | 4.3 |
| `test/prompts/research/topic_decomposition_prompt_test.rb` | Decomposition prompt tests | 5.1 |
| `test/prompts/research/synthesis_prompt_test.rb` | Synthesis prompt tests | 5.4 |
| `test/workflows/goal_decomposition_workflow_test.rb` | Goal decomposition workflow tests | 6.1 |
| `test/workflows/research_workflow_test.rb` | Research workflow tests | 6.2 |
| `test/services/research_output_service_test.rb` | Output service tests | 7.1 |
| `test/controllers/api/v1/research_controller_test.rb` | API endpoint tests | 8.1 |
| `test/integration/codebase_researcher_integration_test.rb` | End-to-end research tests | 8.2 |
| **Comparison Test** | | |
| `test/fixtures/cursor_baseline/research_prompt.md` | Prompt given to both Cursor and worker | 8.3 |
| `test/fixtures/cursor_baseline/cursor_output.md` | Cursor's research output (baseline) | 8.3 |
| `test/integration/research_comparison_test.rb` | Compares worker output to Cursor baseline | 8.3 |

## Document Tree

### Before

```
app/
├── controllers/
│   ├── api/
│   │   └── v1/
│   │       ├── hello_controller.rb
│   │       └── translation_controller.rb
│   ├── application_controller.rb
│   └── dnd_chat_controller.rb
├── models/
│   ├── memories/
│   │   ├── base_memory.rb
│   │   ├── actions_memory.rb
│   │   ├── current_goal_memory.rb
│   │   ├── current_scene_memory.rb
│   │   ├── main_quest_memory.rb
│   │   ├── misc_memory.rb
│   │   ├── people_memory.rb
│   │   ├── quest_log_memory.rb
│   │   ├── quests_memory.rb
│   │   ├── recent_conversation_memory.rb
│   │   ├── registry.rb
│   │   └── training_data/
│   │       └── model_interaction_memory.rb
│   ├── memory_kinds.rb
│   ├── memory_store.rb
│   ├── action_record.rb
│   ├── application_record.rb
│   ├── conversation.rb
│   ├── inventory_item.rb
│   ├── inventory_store.rb
│   ├── message.rb
│   ├── translation_context.rb
│   └── workflow_state.rb
├── prompts/
│   ├── base_prompt.rb
│   ├── action_detection_prompt.rb
│   ├── narrative_prompt.rb
│   ├── outcome_prompt.rb
│   └── translation_prompt.rb
├── services/
│   ├── base_workflow.rb
│   ├── dnd_chat_workflow.rb
│   ├── generic_llm_client.rb
│   ├── thought_extractor.rb
│   ├── tool_call_service.rb
│   ├── translation_service.rb
│   ├── translation_tree_service.rb
│   └── workflow_orchestrator.rb
└── tools/
    ├── base_tool.rb
    ├── bash_tool.rb
    ├── context_compression_tool.rb
    ├── current_context_tool.rb
    ├── dice_roll_tool.rb
    ├── inventory_tool.rb
    ├── memory_summarize_tool.rb
    ├── memory_tool.rb
    ├── read_file_tool.rb
    ├── skill_check_tool.rb
    └── write_file_tool.rb

test/
├── fixtures/
├── integration/
│   ├── dnd_chat_integration_test.rb
│   └── translation_integration_test.rb
├── models/
├── prompts/
├── services/
└── tools/
```

### Added

```
app/
├── controllers/api/v1/
│   └── research_controller.rb
├── models/
│   ├── memories/
│   │   ├── goal_based_memory.rb
│   │   └── research/
│   │       ├── base_research_memory.rb
│   │       ├── context_chain_memory.rb
│   │       ├── discovered_files_memory.rb
│   │       ├── findings_memory.rb
│   │       ├── registry.rb
│   │       ├── research_goal_memory.rb
│   │       └── sub_questions_memory.rb
│   ├── research_memory_kinds.rb
│   └── research_memory_store.rb
├── prompts/research/
│   ├── code_understanding_prompt.rb
│   ├── file_relevance_prompt.rb
│   ├── output_formatting_prompt.rb
│   ├── synthesis_prompt.rb
│   └── topic_decomposition_prompt.rb
├── services/
│   └── research_output_service.rb
├── tools/
│   ├── dependency_graph_tool.rb
│   ├── file_tree_tool.rb
│   └── grep_tool.rb
├── workers/
│   ├── base_worker.rb
│   └── codebase_researcher.rb
└── workflows/
    ├── goal_decomposition_workflow.rb
    └── research_workflow.rb

test/
├── controllers/api/v1/
│   └── research_controller_test.rb
├── fixtures/
│   ├── cursor_baseline/
│   │   ├── cursor_output.md
│   │   └── research_prompt.md
│   └── example_codebase/
│       ├── app/services/
│       │   └── math_service.rb
│       ├── lib/
│       │   ├── calculator.rb
│       │   └── formatter.rb
│       └── README.md
├── integration/
│   ├── codebase_researcher_integration_test.rb
│   └── research_comparison_test.rb
├── models/
│   ├── memories/
│   │   └── goal_based_memory_test.rb
│   └── research_memory_store_test.rb
├── prompts/research/
│   ├── synthesis_prompt_test.rb
│   └── topic_decomposition_prompt_test.rb
├── services/
│   └── research_output_service_test.rb
├── tools/
│   ├── dependency_graph_tool_test.rb
│   ├── file_tree_tool_test.rb
│   └── grep_tool_test.rb
├── workers/
│   ├── base_worker_test.rb
│   └── codebase_researcher_test.rb
└── workflows/
    ├── goal_decomposition_workflow_test.rb
    └── research_workflow_test.rb

.agents/
└── references/
```

