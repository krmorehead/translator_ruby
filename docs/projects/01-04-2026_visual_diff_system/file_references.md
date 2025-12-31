# File References: Visual Diff System

## Overview

Create a visual diff system for reviewing file changes before they're executed or after checkpoints, inspired by Cline's diff preview feature. This enables users to review what agents plan to change, increasing trust and catching errors before execution.

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/services/git_diff_generator.rb` | Git diff generation | Created in Checkpoint project, will be enhanced |
| `app/models/file_diff.rb` | File diff domain object | Created in Checkpoint project |
| `app/models/execution/change_set.rb` | Change set tracking | Created in Act Agent project |
| `app/tools/write_file_tool.rb` | File writing tool | Will preview changes before writing |
| `app/workflows/step_execution_workflow.rb` | Step execution | Will generate preview diffs |
| `frontend/src/components/AgentInspector.jsx` | Agent inspection UI | Will integrate diff viewer |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/services/diff_preview_service.rb` | Preview diffs before execution | Step 1.1 |
| `app/services/unified_diff_parser.rb` | Parse unified diff format | Step 1.2 |
| `app/models/diff_preview.rb` | Diff preview domain object | Step 1.3 |
| `app/models/diff_hunk.rb` | Individual diff hunk | Step 2.1 |
| `app/models/diff_line.rb` | Single line in diff | Step 2.2 |
| `app/controllers/api/v1/diffs_controller.rb` | Diff API endpoints | Step 2.3 |
| `frontend/src/components/DiffViewer.jsx` | Diff visualization component | Step 3.1 |
| `frontend/src/components/DiffLine.jsx` | Single diff line component | Step 3.2 |
| `frontend/src/components/FileChangesSummary.jsx` | Changes summary component | Step 3.3 |
| `frontend/src/hooks/useDiffData.js` | Custom hook for diff data | Step 3.4 |
| `frontend/src/utils/diffHighlighting.js` | Syntax highlighting for diffs | Step 3.5 |
| `test/services/diff_preview_service_test.rb` | Preview service tests | Step 1.1 |
| `test/services/unified_diff_parser_test.rb` | Parser tests | Step 1.2 |
| `test/models/diff_preview_test.rb` | Diff preview tests | Step 1.3 |
| `test/models/diff_hunk_test.rb` | Hunk tests | Step 2.1 |
| `test/models/diff_line_test.rb` | Line tests | Step 2.2 |
| `test/controllers/api/v1/diffs_controller_test.rb` | Controller tests | Step 2.3 |
| `frontend/src/components/__tests__/DiffViewer.test.jsx` | Component tests | Step 3.1 |

## Document Tree

### Before

```
app/
├── services/
│   ├── git_diff_generator.rb (from Checkpoint project)
│   └── step_execution_workflow.rb (from Act Agent)
├── models/
│   ├── file_diff.rb (from Checkpoint project)
│   └── execution/
│       └── change_set.rb (from Act Agent)
├── controllers/
│   └── api/
│       └── v1/
│           └── checkpoints_controller.rb (from Checkpoint)
└── tools/
    └── write_file_tool.rb

frontend/src/
├── components/
│   ├── AgentInspector.jsx
│   └── StateMachineVisualization.jsx (from State Viz)
├── hooks/
│   └── useStateMachine.js (from State Viz)
└── utils/
    └── stateMachineLayout.js (from State Viz)
```

### Added

```
app/
├── services/
│   ├── diff_preview_service.rb
│   └── unified_diff_parser.rb
├── models/
│   ├── diff_preview.rb
│   ├── diff_hunk.rb
│   └── diff_line.rb
└── controllers/
    └── api/
        └── v1/
            └── diffs_controller.rb

frontend/src/
├── components/
│   ├── DiffViewer.jsx
│   ├── DiffLine.jsx
│   └── FileChangesSummary.jsx
├── hooks/
│   └── useDiffData.js
└── utils/
    └── diffHighlighting.js

test/
├── services/
│   ├── diff_preview_service_test.rb
│   └── unified_diff_parser_test.rb
├── models/
│   ├── diff_preview_test.rb
│   ├── diff_hunk_test.rb
│   └── diff_line_test.rb
└── controllers/
    └── api/
        └── v1/
            └── diffs_controller_test.rb
```

