# UnifiedIDE OOP Refactoring Plan

## Current State Analysis

### Issues Identified

1. **God Component**: UnifiedIDE has too many responsibilities
   - Layout management
   - State management (20+ store selectors)
   - Event handling (8+ handlers)
   - Modal management
   - Keyboard shortcuts
   - Checkpoint synchronization

2. **Tight Coupling**: Direct dependency on multiple stores
   - `useAgentStore` (10+ selectors)
   - `useCheckpointStore` (1 selector)
   - Makes testing difficult
   - Hard to reuse components

3. **Mixed Concerns**: UI and business logic intertwined
   - Approval handling logic in UI component
   - File tree loading logic in UI component
   - Session initialization in UI component

4. **Lack of Abstraction**: Repeated patterns
   - Modal management repeated
   - Tab switching logic could be abstracted
   - Panel rendering is repetitive

5. **No Clear Boundaries**: Component responsibilities unclear
   - Where does UnifiedIDE end and child components begin?
   - Which component owns which state?

## OOP Principles to Apply

### 1. Single Responsibility Principle (SRP)
Each component should have ONE reason to change.

### 2. Open/Closed Principle (OCP)
Components should be open for extension, closed for modification.

### 3. Dependency Inversion Principle (DIP)
Depend on abstractions, not concretions.

### 4. Composition Over Inheritance
Build complex UIs from simple, composable parts.

### 5. Separation of Concerns
Separate presentation, business logic, and state management.

## Proposed Architecture

```
UnifiedIDE (Orchestrator)
├── IDEHeader (Presentation)
│   ├── SessionBadge
│   ├── ProjectPathInput
│   └── ActionButtons
├── IDELayout (Structure)
│   ├── LeftPanel
│   │   └── FileTreeBrowser
│   ├── MiddlePanel
│   │   ├── EditorSection
│   │   │   └── CodeEditor
│   │   └── MemorySection
│   │       └── MemoryInspector
│   └── RightPanel
│       ├── AgentControls
│       ├── TabBar
│       └── TabContent
├── ModalManager (Behavior)
│   ├── ApprovalModal
│   ├── ConfigModal
│   └── PreferencesModal
└── KeyboardShortcutHandler (Behavior)
```

## Refactoring Steps

### Phase 1: Extract Presentation Components

#### 1.1 Create IDEHeader Component
**Responsibility**: Display header with session info, project input, and actions

```javascript
// components/ide/IDEHeader.jsx
export function IDEHeader({
  sessionId,
  projectPath,
  onProjectPathChange,
  onLoadProject,
  onInitializeSession,
  onOpenPreferences,
  showInitButton
}) {
  return (
    <header className="ide-header">
      <HeaderLeft sessionId={sessionId} />
      <HeaderCenter 
        projectPath={projectPath}
        onChange={onProjectPathChange}
        onLoad={onLoadProject}
      />
      <HeaderRight
        showInitButton={showInitButton}
        onInitialize={onInitializeSession}
        onPreferences={onOpenPreferences}
      />
    </header>
  );
}
```

#### 1.2 Create AgentControls Component
**Responsibility**: Agent mode selection and configuration access

```javascript
// components/ide/AgentControls.jsx
export function AgentControls({
  mode,
  onModeChange,
  onOpenConfig,
  availableModes = ['daedalus', 'sisyphus', 'researcher']
}) {
  return (
    <div className="agent-controls">
      <AgentModeSelector
        value={mode}
        onChange={onModeChange}
        modes={availableModes}
      />
      <ConfigButton onClick={onOpenConfig} />
    </div>
  );
}
```

#### 1.3 Create TabBar Component
**Responsibility**: Display and manage tab switching

```javascript
// components/ide/TabBar.jsx
export function TabBar({
  activeTab,
  onTabChange,
  tabs = ['chat', 'thoughts', 'context', 'timeline', 'checkpoints']
}) {
  return (
    <div className="agent-tabs">
      {tabs.map(tab => (
        <TabButton
          key={tab}
          tab={tab}
          active={activeTab === tab}
          onClick={() => onTabChange(tab)}
        />
      ))}
    </div>
  );
}
```

### Phase 2: Extract Business Logic

#### 2.1 Create useIDEState Hook
**Responsibility**: Centralize all state management

```javascript
// hooks/useIDEState.js
export function useIDEState() {
  // All store selectors in one place
  const sessionId = useAgentStore(state => state.currentSessionId);
  const mode = useAgentStore(state => state.mode);
  const projectPath = useAgentStore(state => state.projectPath);
  // ... etc
  
  return {
    session: { id: sessionId },
    agent: { mode },
    project: { path: projectPath },
    file: { selected, content },
    approval: { pending, loading },
  };
}
```

#### 2.2 Create useIDEActions Hook
**Responsibility**: Centralize all actions

```javascript
// hooks/useIDEActions.js
export function useIDEActions() {
  const initializeSession = useAgentStore(state => state.initializeSession);
  const setMode = useAgentStore(state => state.setMode);
  // ... etc
  
  return {
    session: {
      initialize: () => initializeSession(mode),
    },
    agent: {
      changeMode: setMode,
    },
    project: {
      setPath: setProjectPath,
      loadFileTree: () => loadFileTree(projectPath),
    },
    file: {
      select: readFile,
    },
    approval: {
      approve: approveRequest,
      reject: rejectRequest,
      close: clearApproval,
    },
  };
}
```

#### 2.3 Create ModalManager Component
**Responsibility**: Manage all modals in one place

```javascript
// components/ide/ModalManager.jsx
export function ModalManager({
  approval,
  config,
  preferences,
  onApprovalApprove,
  onApprovalReject,
  onApprovalClose,
  onConfigClose,
  onPreferencesClose,
}) {
  return (
    <>
      {approval.visible && (
        <ApprovalModal
          approval={approval.data}
          onApprove={onApprovalApprove}
          onReject={onApprovalReject}
          onClose={onApprovalClose}
          loading={approval.loading}
        />
      )}
      {config.visible && (
        <ConfigModal
          onClose={onConfigClose}
        />
      )}
      {preferences.visible && (
        <PreferencesModal
          onClose={onPreferencesClose}
        />
      )}
    </>
  );
}
```

### Phase 3: Implement Composition

#### 3.1 Create Panel Components
**Responsibility**: Encapsulate panel structure

```javascript
// components/ide/Panel.jsx
export function Panel({ title, icon, children, className = '' }) {
  return (
    <div className={`panel ${className}`}>
      <PanelHeader title={title} icon={icon} />
      <PanelContent>{children}</PanelContent>
    </div>
  );
}
```

#### 3.2 Refactor UnifiedIDE to use Composition

```javascript
// components/UnifiedIDE.jsx (Refactored)
export function UnifiedIDE() {
  // Local UI state only
  const [activeTab, setActiveTab] = useState("chat");
  const [modals, setModals] = useState({
    config: false,
    preferences: false,
  });
  
  // Business logic hooks
  const state = useIDEState();
  const actions = useIDEActions();
  const shortcuts = useIDEKeyboardShortcuts(actions, state);
  
  return (
    <div className="unified-ide">
      <ModalManager
        approval={{
          visible: !!state.approval.pending,
          data: state.approval.pending,
          loading: state.approval.loading,
        }}
        config={{ visible: modals.config }}
        preferences={{ visible: modals.preferences }}
        onApprovalApprove={actions.approval.approve}
        onApprovalReject={actions.approval.reject}
        onApprovalClose={actions.approval.close}
        onConfigClose={() => setModals(m => ({ ...m, config: false }))}
        onPreferencesClose={() => setModals(m => ({ ...m, preferences: false }))}
      />
      
      <IDEHeader
        sessionId={state.session.id}
        projectPath={state.project.path}
        onProjectPathChange={actions.project.setPath}
        onLoadProject={actions.project.loadFileTree}
        onInitializeSession={actions.session.initialize}
        onOpenPreferences={() => setModals(m => ({ ...m, preferences: true }))}
        showInitButton={!state.session.id}
      />
      
      {state.session.id && <PersistentContextBar />}
      
      <IDELayout
        leftPanel={
          <Panel title="Files" icon="📁">
            <FileTreeBrowser onFileSelect={actions.file.select} />
          </Panel>
        }
        middlePanel={
          <>
            <Panel title="Editor" icon="📝" className="editor-section">
              <CodeEditor
                filePath={state.file.selected}
                content={state.file.content}
                readOnly={!state.project.path}
              />
            </Panel>
            <Panel title="Memory" icon="🧠" className="memory-section">
              <MemoryInspector />
            </Panel>
          </>
        }
        rightPanel={
          <Panel title="Agent" icon="🤖">
            <AgentControls
              mode={state.agent.mode}
              onModeChange={actions.agent.changeMode}
              onOpenConfig={() => setModals(m => ({ ...m, config: true }))}
            />
            {state.session.id && (
              <>
                <TabBar
                  activeTab={activeTab}
                  onTabChange={setActiveTab}
                />
                <TabContent activeTab={activeTab} />
              </>
            )}
            {!state.session.id && <EmptyState />}
          </Panel>
        }
      />
    </div>
  );
}
```

## Benefits of This Approach

### 1. Testability
- Each component can be tested in isolation
- Mock only what you need
- Clear interfaces

### 2. Reusability
- Panel component can be reused anywhere
- AgentControls can be used outside IDE
- TabBar is generic

### 3. Maintainability
- Clear responsibilities
- Easy to find code
- Changes are localized

### 4. Scalability
- Easy to add new tabs
- Easy to add new panels
- Easy to add new modals

### 5. Performance
- Can memoize individual components
- Smaller re-render boundaries
- Better React DevTools experience

## Implementation Order

1. ✅ Create folder structure
2. ✅ Extract hooks (useIDEState, useIDEActions)
3. ✅ Extract presentation components (IDEHeader, AgentControls, TabBar)
4. ✅ Extract structural components (Panel, IDELayout)
5. ✅ Extract behavioral components (ModalManager)
6. ✅ Refactor UnifiedIDE to use new components
7. ✅ Update tests
8. ✅ Verify all functionality works
9. ✅ Clean up old code

## File Structure

```
frontend/src/
├── components/
│   ├── ide/                    # NEW: IDE-specific components
│   │   ├── UnifiedIDE.jsx      # Main orchestrator (refactored)
│   │   ├── IDEHeader.jsx       # Header component
│   │   ├── IDELayout.jsx       # Layout structure
│   │   ├── Panel.jsx           # Generic panel
│   │   ├── AgentControls.jsx  # Agent controls
│   │   ├── TabBar.jsx          # Tab navigation
│   │   ├── TabContent.jsx      # Tab content router
│   │   ├── ModalManager.jsx    # Modal orchestrator
│   │   └── EmptyState.jsx      # Empty state display
│   ├── FileTreeBrowser.jsx     # Existing
│   ├── CodeEditor.jsx          # Existing
│   ├── ChatPanel.jsx           # Existing
│   └── ...
├── hooks/
│   ├── ide/                    # NEW: IDE-specific hooks
│   │   ├── useIDEState.js      # State aggregation
│   │   ├── useIDEActions.js    # Action aggregation
│   │   └── useIDEKeyboardShortcuts.js  # Keyboard handling
│   └── ...
└── ...
```

## Success Criteria

- ✅ UnifiedIDE < 150 lines
- ✅ Each component < 100 lines
- ✅ Clear, single responsibilities
- ✅ All tests passing
- ✅ No functionality lost
- ✅ Better performance
- ✅ Easier to understand
- ✅ Follows OOP principles

## Next Steps

1. Create the new folder structure
2. Implement hooks first (foundation)
3. Implement presentation components
4. Refactor UnifiedIDE
5. Update tests
6. Document the new architecture

