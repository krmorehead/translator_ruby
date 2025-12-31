# File References: State Visualization

## Overview

Create a real-time state machine visualization for the frontend that shows Worker and Workflow states, transitions, and progress. This provides transparency into what agents are doing and builds user confidence in autonomous operation.

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/workers/base_worker.rb` | Base worker with state machine | Source of state data |
| `app/services/base_workflow.rb` | Base workflow with state machine | Source of workflow states |
| `app/models/workflow_memory_store.rb` | Memory with state transitions | State history storage |
| `lib/concerns/state_machine.rb` | State machine concern | Defines states and transitions |
| `frontend/src/components/AgentInspector.jsx` | Agent inspection UI | Will integrate visualization |
| `frontend/src/api/dndChatApi.js` | API client | Will fetch state data |
| `frontend/src/store/chatStore.js` | Frontend state management | Will store visualization data |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/serializers/state_machine_serializer.rb` | State machine JSON serializer | Step 1.1 |
| `app/serializers/state_transition_serializer.rb` | State transition serializer | Step 1.2 |
| `app/controllers/api/v1/state_machines_controller.rb` | API endpoint for state data | Step 1.3 |
| `app/models/active_worker_registry.rb` | Registry for tracking active workers | Step 1.4 |
| `config/routes.rb` | Add state machine routes | Step 1.3 |
| `frontend/src/components/StateMachineVisualization.jsx` | State graph visualization component | Step 2.1 |
| `frontend/src/components/StateTransitionLog.jsx` | Transition history log component | Step 2.2 |
| `frontend/src/components/WorkerProgressBar.jsx` | Progress indicator component | Step 2.3 |
| `frontend/src/hooks/useStateMachine.js` | Custom hook for state data | Step 3.1 |
| `frontend/src/utils/stateMachineLayout.js` | Graph layout algorithm | Step 3.2 |
| `test/serializers/state_machine_serializer_test.rb` | Serializer tests | Step 1.1 |
| `test/serializers/state_transition_serializer_test.rb` | Transition serializer tests | Step 1.2 |
| `test/controllers/api/v1/state_machines_controller_test.rb` | Controller tests | Step 1.3 |
| `test/models/active_worker_registry_test.rb` | Worker registry tests | Step 1.4 |
| `frontend/src/components/__tests__/StateMachineVisualization.test.jsx` | Component tests | Step 2.1 |

## Document Tree

### Before

```
app/
├── workers/
│   ├── base_worker.rb
│   ├── plan_agent_worker.rb
│   └── act_agent_worker.rb
├── services/
│   └── base_workflow.rb
├── models/
│   └── workflow_memory_store.rb
├── serializers/
│   └── chat_response_serializer.rb
├── controllers/
│   └── api/
│       └── v1/
│           └── translation_controller.rb
└── lib/
    └── concerns/
        └── state_machine.rb

frontend/src/
├── components/
│   ├── AgentInspector.jsx
│   ├── ChatLog.jsx
│   └── MessageInput.jsx
├── api/
│   └── dndChatApi.js
├── store/
│   └── chatStore.js
└── hooks/
    └── (empty)
```

### Added

```
app/
├── serializers/
│   ├── state_machine_serializer.rb
│   └── state_transition_serializer.rb
├── models/
│   └── active_worker_registry.rb
└── controllers/
    └── api/
        └── v1/
            └── state_machines_controller.rb

frontend/src/
├── components/
│   ├── StateMachineVisualization.jsx
│   ├── StateTransitionLog.jsx
│   └── WorkerProgressBar.jsx
├── hooks/
│   └── useStateMachine.js
└── utils/
    └── stateMachineLayout.js

test/
├── serializers/
│   ├── state_machine_serializer_test.rb
│   └── state_transition_serializer_test.rb
├── models/
│   └── active_worker_registry_test.rb
└── controllers/
    └── api/
        └── v1/
            └── state_machines_controller_test.rb
```

