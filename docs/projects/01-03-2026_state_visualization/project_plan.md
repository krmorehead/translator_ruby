# Project Plan: State Visualization

## Overview

Create a real-time state machine visualization system for the frontend that displays Worker and Workflow states, transitions, and progress. This addresses one of the key UX gaps identified in the Cline comparison: users need visibility into what agents are doing. The visualization will show state graphs, transition history, and progress indicators to build user confidence.

## Goals

- Visualize state machines as interactive graphs
- Display real-time state transitions
- Show workflow progress as percentage
- Display transition history log
- Enable SSE streaming for live updates
- Make state information accessible and understandable
- Build user confidence through transparency

---

## Milestone 1 - Backend State Serialization

Create serializers and API endpoints for exposing state machine data.

### 1.1 - Create StateMachineSerializer

**Intent**: Create a serializer that converts Worker/Workflow state machines into JSON format suitable for frontend visualization.

**Details**:
- Create in app/serializers/state_machine_serializer.rb
- Accept worker or workflow instance
- Extract state machine definition: states, transitions, current_state
- Serialize to JSON with structure:
  ```json
  {
    "id": "worker_id",
    "type": "Worker|Workflow",
    "current_state": "running",
    "states": [
      { "name": "pending", "description": "...", "phase": null },
      { "name": "running", "description": "...", "phase": "setup" }
    ],
    "transitions": [
      { "from": "pending", "to": "running", "on": "start" }
    ],
    "metadata": { "worker_name": "PlanAgentWorker", "started_at": "..." }
  }
  ```
- Include phase information for each state (used for grouping)
- Include transition history from memory_store
- Follow Rails serializer patterns

**Tests**:
- Test serialization of Worker state machine
- Test serialization of Workflow state machine
- Test current_state inclusion
- Test states array format
- Test transitions array format
- Test metadata inclusion

---

### 1.2 - Create StateTransitionSerializer

**Intent**: Create a serializer for individual state transitions to show transition history.

**Details**:
- Create in app/serializers/state_transition_serializer.rb
- Serialize individual transition records from memory
- JSON structure:
  ```json
  {
    "from": "pending",
    "to": "running",
    "event": "start",
    "timestamp": "2026-01-01T10:00:00Z",
    "duration_in_state": 1.5,
    "payload": { ... }
  }
  ```
- Include duration in previous state
- Include any payload data from transition
- Sort by timestamp (most recent first)
- Limit to recent N transitions (default 50)

**Tests**:
- Test transition serialization format
- Test timestamp formatting
- Test duration calculation
- Test payload inclusion
- Test sorting by timestamp
- Test limit enforcement

---

### 1.3 - Create StateMachinesController

**Intent**: Create API endpoints for frontend to fetch state machine data and subscribe to updates.

**Details**:
- Create app/controllers/api/v1/state_machines_controller.rb
- Routes in config/routes.rb:
  - GET /api/v1/state_machines/:worker_id - get state machine for worker
  - GET /api/v1/state_machines/:worker_id/transitions - get transition history
  - GET /api/v1/state_machines - list all active workers (uses ActiveWorkerRegistry)
  - GET /api/v1/state_machines/:worker_id/stream - SSE stream of state changes (future)
- Methods: index, show, transitions
- Use StateMachineSerializer and StateTransitionSerializer
- Accept worker_id parameter (owner_id from workers)
- Fetch worker instance from ActiveWorkerRegistry (see Step 1.4)
- Handle errors: worker not found, invalid ID
- Return JSON responses

**Tests**:
- Test GET /state_machines returns list of active workers
- Test GET /state_machines/:id returns state machine JSON
- Test GET /state_machines/:id/transitions returns transition list
- Test error handling for missing workers
- Test JSON response format matches serializer
- Test controller integration

---

### 1.4 - Create ActiveWorkerRegistry

**Intent**: Create a registry for tracking active workers so the frontend can discover and query them. This enables the State Visualization frontend to find running workers.

**Details**:
- Create app/models/active_worker_registry.rb as a singleton
- Use thread-safe data structure (Concurrent::Map or similar)
- Methods:
  - register(worker) → add worker to registry with owner_id as key
  - unregister(worker) → remove worker from registry
  - find(worker_id) → retrieve worker by owner_id
  - list_active → array of all active worker IDs with metadata
  - count → number of active workers
  - clear → remove all workers (for testing)
- Store worker metadata: worker_id, worker_class, goal, started_at, current_state
- Workers auto-register on initialization (update BaseWorker to call registry.register(self))
- Workers auto-unregister on completion or failure
- Thread-safe for concurrent worker execution
- Optional: Add TTL/expiration for stale workers (cleanup after N hours)
- Persist registry to Redis (future enhancement) or keep in-memory

**Tests**:
- Test singleton pattern (same instance returned)
- Test register adds worker to registry
- Test unregister removes worker
- Test find retrieves correct worker
- Test list_active returns all workers
- Test count returns correct number
- Test clear removes all workers
- Test thread safety with concurrent access
- Test metadata storage and retrieval

---

### 1.5 - Integrate Registry with BaseWorker

**Intent**: Update BaseWorker to automatically register/unregister workers with ActiveWorkerRegistry.

**Details**:
- In BaseWorker.initialize, call ActiveWorkerRegistry.instance.register(self)
- In BaseWorker state transition hooks:
  - On transition to :complete → unregister
  - On transition to :failed → unregister
- Add disable_registry flag for testing (prevents registration)
- Ensure registry operations don't break worker execution (wrap in rescue)
- Log registration/unregistration for debugging

**Tests**:
- Test worker registers on initialization
- Test worker unregisters on complete
- Test worker unregisters on failed
- Test disable_registry flag prevents registration
- Test registry errors don't crash worker
- Test multiple workers register correctly

---

## Milestone 2 - Frontend Visualization Components

Create React components for visualizing state machines.

### 2.1 - Create StateMachineVisualization Component

**Intent**: Create the main visualization component that renders state machines as interactive graphs using D3.js or React Flow.

**Details**:
- Create frontend/src/components/StateMachineVisualization.jsx
- Use React Flow library for graph visualization (or D3.js)
- Props: stateMachineData (from API), isLive (enable real-time updates)
- Render nodes for each state:
  - Shape: rounded rectangle
  - Color: based on state (current=blue, completed=green, pending=gray, failed=red)
  - Label: state name + description
  - Phase indicator (if present)
- Render edges for each transition:
  - Arrow from source to target
  - Label: event name
  - Color: gray (default), blue (active transition)
- Highlight current state with border and pulse animation
- Support zoom and pan
- Support node click to show state details
- Responsive layout (fit to container)

**Tests**:
- Test component renders with state machine data
- Test nodes rendered for each state
- Test edges rendered for each transition
- Test current state highlighting
- Test click handlers
- Test responsive behavior

---

### 2.2 - Create StateTransitionLog Component

**Intent**: Create a log component that displays the history of state transitions in chronological order.

**Details**:
- Create frontend/src/components/StateTransitionLog.jsx
- Props: transitions (array of transition objects), maxHeight (default 400px)
- Display transitions in reverse chronological order (most recent first)
- Each transition shows:
  - Timestamp (relative: "2 minutes ago")
  - From state → To state (with arrow icon)
  - Event name
  - Duration in previous state
  - Expand/collapse for payload details
- Color code by transition type (normal, error, retry)
- Scrollable with max height
- Auto-scroll to bottom on new transitions (if isLive)
- Filter controls: by state, by event type
- Search transitions by state name or event

**Tests**:
- Test component renders transition list
- Test chronological ordering
- Test timestamp formatting
- Test expand/collapse functionality
- Test filter controls
- Test search functionality

---

### 2.3 - Create WorkerProgressBar Component

**Intent**: Create a progress indicator showing Worker/Workflow completion percentage.

**Details**:
- Create frontend/src/components/WorkerProgressBar.jsx
- Props: stateMachineData, currentMilestone, totalMilestones
- Calculate progress percentage based on:
  - For Workers: (completed_milestones / total_milestones) * 100
  - For Workflows: derived from state (pending=0%, running=50%, complete=100%)
- Display progress bar with:
  - Percentage label
  - Current state name
  - Estimated time remaining (if available)
  - Color gradient (blue → green as progress increases)
- Show sub-progress for current milestone/step
- Animate progress changes smoothly
- Display status badge (running, complete, failed)

**Tests**:
- Test progress calculation for Workers
- Test progress calculation for Workflows
- Test percentage display
- Test status badge rendering
- Test animation on updates
- Test color gradient application

---

## Milestone 3 - Real-Time Updates and Integration

Enable live state updates and integrate visualization into existing UI.

### 3.1 - Create useStateMachine Hook

**Intent**: Create a custom React hook for fetching and managing state machine data with real-time updates.

**Details**:
- Create frontend/src/hooks/useStateMachine.js
- Accept workerId parameter
- Fetch initial state machine data from API
- Poll for updates every N seconds (default 2s)
- Optionally use SSE for real-time updates (future enhancement)
- Return object: { stateMachine, transitions, isLoading, error, refresh }
- Cache fetched data in React state
- Handle errors gracefully (retry with exponential backoff)
- Cleanup on unmount (stop polling, close SSE connection)
- Provide manual refresh function

**Tests**:
- Test hook fetches initial data
- Test polling updates trigger re-renders
- Test error handling and retry logic
- Test cleanup on unmount
- Test manual refresh
- Test caching behavior

---

### 3.2 - Create State Machine Layout Algorithm

**Intent**: Create a utility for calculating optimal layout positions for state machine graphs.

**Details**:
- Create frontend/src/utils/stateMachineLayout.js
- Accept states and transitions arrays
- Calculate node positions using layered layout algorithm:
  - Layer 0: initial states
  - Layer N: states reachable in N transitions
  - Within layer: distribute evenly
- Return positions: { stateId: { x, y } }
- Handle cycles gracefully (backward edges)
- Minimize edge crossings
- Support different layout directions (left-to-right, top-to-bottom)
- Alternative: use dagre library for automatic layout

**Tests**:
- Test layout calculation for simple state machine
- Test layout handles cycles
- Test layout distributes nodes evenly
- Test different layout directions
- Test edge case: single state

---

### 3.3 - Integrate into AgentInspector

**Intent**: Integrate state visualization components into the existing AgentInspector UI.

**Details**:
- Update frontend/src/components/AgentInspector.jsx
- Add tabs or sections for:
  - "State Graph" - StateMachineVisualization
  - "Transition Log" - StateTransitionLog
  - "Progress" - WorkerProgressBar
- Fetch workerId from current chat session or selected worker
- Use useStateMachine hook for data
- Add toggle for live updates
- Add refresh button
- Handle no worker selected state
- Responsive layout for different screen sizes

**Tests**:
- Test AgentInspector renders state visualization
- Test tab switching
- Test live updates toggle
- Test refresh button
- Test no worker selected state
- Test responsive behavior

---

## Milestone 4 - Polish and Advanced Features

Add polish and advanced visualization features.

### 4.1 - Add State Machine Metrics

**Intent**: Display useful metrics about state machine execution.

**Details**:
- Add metrics panel showing:
  - Total time in current state
  - Average time per state
  - Total transitions
  - Failed transitions count
  - Most common transition path
- Calculate metrics from transition history
- Display in sidebar or info panel
- Update in real-time
- Format durations nicely (1m 30s, 2h 15m, etc.)

**Tests**:
- Test metric calculations
- Test duration formatting
- Test real-time updates
- Test metric display

---

### 4.2 - Add State Machine Export

**Intent**: Enable exporting state machine diagrams and data.

**Details**:
- Add export button to StateMachineVisualization
- Export formats:
  - PNG image (render SVG to canvas, download)
  - JSON data (state machine and transition history)
  - Markdown report (text summary)
- Use html-to-image or similar library for image export
- Generate filename with timestamp and worker ID
- Include metadata in exports (timestamp, worker name)

**Tests**:
- Test PNG export generates image
- Test JSON export includes all data
- Test Markdown export formatting
- Test filename generation
- Test download trigger

---

### 4.3 - Add State Machine Animation

**Intent**: Add smooth animations for state transitions to make visualization more engaging.

**Details**:
- Animate state changes:
  - Pulse animation on current state
  - Transition edge highlight when transition occurs
  - Color fade-in/fade-out on state changes
- Use CSS transitions and React Spring for smooth animations
- Animate progress bar updates
- Add particle effect for completed transitions (optional, subtle)
- Keep animations subtle and professional
- Provide option to disable animations (accessibility)

**Tests**:
- Test animation triggers on state change
- Test pulse animation on current state
- Test edge highlighting
- Test progress bar animation
- Manual review of animation smoothness

---

## Milestone 5 - Documentation and Testing

Complete with documentation and comprehensive testing.

### 5.1 - Create Documentation

**Intent**: Document the state visualization system for developers and users.

**Details**:
- Create docs/references/state_visualization.md
- Document: architecture, API endpoints, frontend components
- Explain state machine serialization format
- Provide usage examples: integrating visualization, customizing layout
- Document real-time update strategy
- Include component prop documentation
- Document metrics calculations
- Provide troubleshooting guide

**Tests**:
- Manual review of documentation completeness
- Verify all examples are accurate
- Check API documentation matches implementation

---

### 5.2 - Integration Testing

**Intent**: Create end-to-end tests for state visualization.

**Details**:
- Create test/integration/state_visualization_integration_test.rb
- Test scenarios:
  1. Worker runs through complete state machine, visualization updates
  2. Frontend fetches state machine data via API
  3. State transitions are captured and displayed
  4. Progress bar updates as worker progresses
  5. Multiple workers tracked simultaneously
- Use ActAgentWorker or PlanAgentWorker for real scenarios
- Verify API responses match serializer format
- Verify frontend components render correctly

**Tests**:
- Integration test: complete worker lifecycle with visualization
- Integration test: API endpoint responses
- Integration test: real-time updates (polling)
- Integration test: multiple workers
- Integration test: error handling

---

### 5.3 - Performance Optimization

**Intent**: Ensure visualization performs well with large state machines and frequent updates.

**Details**:
- Optimize React rendering: use React.memo for components
- Debounce API polls when page is inactive
- Limit transition history to recent N (50-100)
- Use virtual scrolling for long transition lists
- Optimize graph layout calculation (cache results)
- Lazy load state machine data (only fetch when tab is active)
- Add loading skeletons for better perceived performance
- Monitor and log performance metrics

**Tests**:
- Performance test: large state machine (50+ states)
- Performance test: frequent updates (every 100ms)
- Performance test: long transition history (1000+ transitions)
- Measure render times and API response times
- Verify optimizations improve performance

---

## Execution Guidelines

1. Implement backend (Milestone 1) before frontend (Milestones 2-3)
2. Write tests for both Rails and React components
3. Use existing component patterns from ChatLog and AgentInspector
4. Keep visualizations simple and clean (don't over-design)
5. Test with real Workers (PlanAgent, ActAgent) for realistic scenarios
6. Prioritize clarity over complexity
7. Run full test suite after each step
8. Commit after each milestone
9. Update file_references.md as files are created

## Success Criteria

- [ ] State machines visualized as interactive graphs
- [ ] Current state clearly highlighted and identifiable
- [ ] Transition history displayed in log format
- [ ] Progress indicators show completion percentage
- [ ] Real-time updates work (polling or SSE)
- [ ] API endpoints return correct state machine data
- [ ] All tests pass with >85% coverage
- [ ] Visualization integrated into AgentInspector
- [ ] Documentation is complete and accurate
- [ ] Performance is acceptable with typical workloads

## Design Guidelines

**Visual Principles:**
- Keep it clean and professional (not a toy)
- Use consistent color coding (blue=active, green=complete, red=failed, gray=pending)
- Make current state obvious (larger, highlighted, animated)
- Use subtle animations (no distracting effects)
- Ensure good contrast for accessibility
- Support both light and dark modes
- Mobile-responsive (though desktop is primary target)

**UX Principles:**
- Show most important information first (current state, progress)
- Make history accessible but not overwhelming
- Provide controls (pause updates, export, filter)
- Handle errors gracefully (show fallback UI)
- Load quickly (show skeleton while loading)
- Update smoothly (no jarring changes)
- Explain what's happening (tooltips, descriptions)

