# File References: Git Checkpoint System

## Overview

Implement a comprehensive Git-based checkpoint system inspired by Cline's snapshot/rollback feature. This provides safety and auditability for agent actions by creating automatic Git commits at key workflow boundaries with diff generation and rollback capabilities.

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/services/checkpoint_service.rb` | Basic checkpoint service | Created in Act Agent project, will be enhanced |
| `app/workers/base_worker.rb` | Base worker class | Will integrate checkpoint hooks |
| `app/services/base_workflow.rb` | Base workflow class | Will integrate checkpoint triggers |
| `app/tools/bash_tool.rb` | Bash command execution | Used for git commands |
| `app/models/workflow_memory_store.rb` | Workflow memory | Will store checkpoint metadata |
| `test/services/checkpoint_service_test.rb` | Checkpoint tests | Created in Act Agent, will be expanded |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/services/git_checkpoint_manager.rb` | Enhanced checkpoint management | Step 1.1 |
| `app/services/git_diff_generator.rb` | Diff generation service | Step 1.2 |
| `app/services/git_rollback_service.rb` | Rollback and restore service | Step 1.3 |
| `app/models/checkpoint.rb` | Checkpoint domain object | Step 2.1 |
| `app/models/checkpoint_registry.rb` | Registry of all checkpoints | Step 2.2 |
| `app/models/file_diff.rb` | Individual file diff object | Step 2.3 |
| `lib/concerns/checkpointable.rb` | Mixin for checkpoint-aware classes | Step 3.1 |
| `app/services/checkpoint_policy.rb` | Policy for when to create checkpoints | Step 3.2 |
| `test/services/git_checkpoint_manager_test.rb` | Checkpoint manager tests | Step 1.1 |
| `test/services/git_diff_generator_test.rb` | Diff generator tests | Step 1.2 |
| `test/services/git_rollback_service_test.rb` | Rollback service tests | Step 1.3 |
| `test/models/checkpoint_test.rb` | Checkpoint model tests | Step 2.1 |
| `test/models/checkpoint_registry_test.rb` | Registry tests | Step 2.2 |
| `test/models/file_diff_test.rb` | File diff tests | Step 2.3 |
| `test/lib/concerns/checkpointable_test.rb` | Checkpointable concern tests | Step 3.1 |
| `test/integration/checkpoint_integration_test.rb` | Integration tests | Step 4.1 |

## Document Tree

### Before

```
app/
├── services/
│   ├── checkpoint_service.rb (basic, from Act Agent)
│   ├── base_workflow.rb
│   └── generic_llm_client.rb
├── workers/
│   └── base_worker.rb
├── models/
│   └── workflow_memory_store.rb
└── tools/
    └── bash_tool.rb

lib/
└── concerns/
    └── (empty)

test/
├── services/
│   └── checkpoint_service_test.rb
└── integration/
    └── (various tests)
```

### Added

```
app/
├── services/
│   ├── git_checkpoint_manager.rb
│   ├── git_diff_generator.rb
│   ├── git_rollback_service.rb
│   └── checkpoint_policy.rb
└── models/
    ├── checkpoint.rb
    ├── checkpoint_registry.rb
    └── file_diff.rb

lib/
└── concerns/
    └── checkpointable.rb

test/
├── services/
│   ├── git_checkpoint_manager_test.rb
│   ├── git_diff_generator_test.rb
│   ├── git_rollback_service_test.rb
│   └── checkpoint_policy_test.rb
├── models/
│   ├── checkpoint_test.rb
│   ├── checkpoint_registry_test.rb
│   └── file_diff_test.rb
├── lib/
│   └── concerns/
│       └── checkpointable_test.rb
└── integration/
    └── checkpoint_integration_test.rb
```

