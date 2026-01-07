---
description: UI component architecture and composition patterns
globs: app/frontend/components/**/*.tsx
alwaysApply: false
---

# UI Component Architecture & Composition

**Tags**: [architecture, design, front_end]  
**Applies To**: Any component-based UI (React as reference)  
**Date**: 2026-01-05

## Overview

Component composition patterns enable building complex UIs from simple, reusable pieces. This guide covers the Single Responsibility Principle (SRP), composition over inheritance, and proper separation of presentation from business logic.

**When to use these patterns:**
- Building complex UIs
- Components have too many responsibilities
- State management is tightly coupled
- Components are difficult to test or reuse

---

## Rules

### [ARCH][!SINGLE-RESPONSIBILITY]

**Rule**: Each component should have ONE clear responsibility. If a component does multiple things, split it.

**Bad Example:**

```jsx
// ❌ God Component - does everything
function UnifiedIDE() {
  // State management (20+ pieces of state)
  const [activeTab, setActiveTab] = useState("chat");
  const [projectPath, setProjectPath] = useState("");
  const [selectedFile, setSelectedFile] = useState(null);
  const [fileContent, setFileContent] = useState("");
  const [configModal, setConfigModal] = useState(false);
  const [prefsModal, setPrefsModal] = useState(false);
  // ... 15 more state variables
  
  // Event handlers (8+)
  const handleLoadProject = () => { /* ... 50 lines */ };
  const handleFileSelect = () => { /* ... 30 lines */ };
  const handleTabChange = () => { /* ... 20 lines */ };
  // ... many more handlers
  
  // Render (200+ lines)
  return (
    <div className="unified-ide">
      {/* Header */}
      <header>
        <div className="session-info">
          {sessionId && <Badge>{sessionId}</Badge>}
        </div>
        <input value={projectPath} onChange={e => setProjectPath(e.target.value)} />
        <button onClick={handleLoadProject}>Load Project</button>
        <button onClick={() => setPrefsModal(true)}>Preferences</button>
      </header>
      
      {/* File Tree */}
      <div className="file-tree">
        {loading && <Spinner />}
        {error && <Error>{error}</Error>}
        {tree && renderFileTree(tree)}  {/* Inline rendering */}
      </div>
      
      {/* Code Editor */}
      <div className="editor">
        {selectedFile ? (
          <MonacoEditor value={fileContent} />
        ) : (
          <EmptyState />
        )}
      </div>
      
      {/* Agent Controls */}
      <div className="agent">
        <select value={mode} onChange={e => setMode(e.target.value)}>
          <option value="daedalus">Daedalus</option>
          <option value="sisyphus">Sisyphus</option>
        </select>
        <button onClick={() => setConfigModal(true)}>Config</button>
        
        {/* Tabs */}
        <div className="tabs">
          <button onClick={() => setActiveTab("chat")}>Chat</button>
          <button onClick={() => setActiveTab("thoughts")}>Thoughts</button>
          {/* ... more tabs */}
        </div>
        
        {/* Tab Content */}
        {activeTab === "chat" && <ChatPanel />}
        {activeTab === "thoughts" && <ThoughtsPanel />}
        {/* ... more tab content */}
      </div>
      
      {/* Modals */}
      {configModal && <ConfigModal onClose={() => setConfigModal(false)} />}
      {prefsModal && <PrefsModal onClose={() => setPrefsModal(false)} />}
    </div>
  );
}

// Result: 400+ line component, impossible to test, hard to maintain
```

**Good Example:**

```jsx
// ✅ Orchestrator component with single responsibility
function UnifiedIDE() {
  // Only local UI state
  const [activeTab, setActiveTab] = useState("chat");
  const [modals, setModals] = useState({ config: false, preferences: false });
  
  // Business logic hooks (extracted)
  const state = useIDEState();
  const actions = useIDEActions();
  
  return (
    <div className="unified-ide">
      <ModalManager
        modals={modals}
        onClose={(name) => setModals(m => ({...m, [name]: false}))}
        approval={state.approval}
        actions={actions}
      />
      
      <IDEHeader
        sessionId={state.session.id}
        projectPath={state.project.path}
        onProjectPathChange={actions.project.setPath}
        onLoadProject={actions.project.loadFileTree}
        onInitialize={actions.session.initialize}
        onPreferences={() => setModals(m => ({...m, preferences: true}))}
      />
      
      {state.session.id && <PersistentContextBar />}
      
      <IDELayout
        leftPanel={<FileTreeBrowser onFileSelect={actions.file.select} />}
        middlePanel={<CodeEditor file={state.file} />}
        rightPanel={
          <AgentPanel
            mode={state.agent.mode}
            onModeChange={actions.agent.changeMode}
            onConfig={() => setModals(m => ({...m, config: true}))}
            activeTab={activeTab}
            onTabChange={setActiveTab}
          />
        }
      />
    </div>
  );
}

// Result: ~50 line orchestrator, clear responsibilities
```

**Why**: Small, focused components are testable, reusable, and easy to understand. Changes are localized.

---

### [ARCH][!COMPOSITION-OVER-INHERITANCE]

**Rule**: Build complex UIs by composing simple components, not through class inheritance.

**Bad Example:**

```jsx
// ❌ Deep inheritance hierarchy
class BasePanel extends React.Component {
  render() {
    return <div className="panel">{this.renderContent()}</div>;
  }
}

class TitlePanel extends BasePanel {
  renderContent() {
    return (
      <div>
        <h3>{this.renderTitle()}</h3>
        {super.renderContent()}
      </div>
    );
  }
}

class IconTitlePanel extends TitlePanel {
  renderTitle() {
    return (
      <span>
        {this.renderIcon()}
        {this.props.title}
      </span>
    );
  }
}

// Problem: Deep inheritance, hard to understand flow
```

**Good Example:**

```jsx
// ✅ Composition with simple components
function Panel({ title, icon, children, className = '' }) {
  return (
    <div className={`panel ${className}`}>
      {(title && icon) && (
        <PanelHeader title={title} icon={icon} />
      )}
      <PanelContent>{children}</PanelContent>
    </div>
  );
}

function PanelHeader({ title, icon }) {
  return (
    <div className="panel-header">
      {icon && <span className="icon">{icon}</span>}
      {title && <h3>{title}</h3>}
    </div>
  );
}

function PanelContent({ children }) {
  return <div className="panel-content">{children}</div>;
}

// Usage - compose as needed
<Panel title="Files" icon="📁">
  <FileTreeBrowser />
</Panel>

<Panel title="Editor" icon="📝" className="editor-section">
  <CodeEditor />
</Panel>
```

**Why**: Composition is flexible, understandable, and doesn't require understanding inheritance chains.

---

### [ARCH][!PROPS-DOWN-EVENTS-UP]

**Rule**: Data flows down through props, events flow up through callbacks. One-way data flow.

**Bad Example:**

```jsx
// ❌ Child mutates parent state directly
function Parent() {
  const [data, setData] = useState({ count: 0 });
  
  return <Child data={data} />;  // Passing mutable reference
}

function Child({ data }) {
  const increment = () => {
    data.count++;  // Directly mutating parent state!
  };
  
  return <button onClick={increment}>Increment</button>;
}

// Result: State mutations are invisible, hard to track
```

**Good Example:**

```jsx
// ✅ Props down, events up
function Parent() {
  const [count, setCount] = useState(0);
  
  const handleIncrement = () => setCount(c => c + 1);
  
  return (
    <Child 
      count={count}           // Data flows down
      onIncrement={handleIncrement}  // Events flow up
    />
  );
}

function Child({ count, onIncrement }) {
  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={onIncrement}>Increment</button>
    </div>
  );
}

// Result: Clear data flow, easy to trace changes
```

**Why**: One-way data flow makes state changes predictable and easy to debug.

---

### [ARCH][!EXTRACT-BUSINESS-LOGIC-TO-HOOKS]

**Rule**: Extract business logic from components into custom hooks. Components should be pure presentation.

**Bad Example:**

```jsx
// ❌ Business logic mixed with presentation
function AgentPanel() {
  const [mode, setMode] = useState('daedalus');
  const [session, setSession] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(false);
  
  const initializeSession = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/sessions', {
        method: 'POST',
        body: JSON.stringify({ mode })
      });
      const data = await response.json();
      setSession(data.session);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };
  
  const sendMessage = async (content) => {
    const response = await fetch(`/api/sessions/${session.id}/messages`, {
      method: 'POST',
      body: JSON.stringify({ content })
    });
    const data = await response.json();
    setMessages(m => [...m, data.message]);
  };
  
  // ... 200 more lines of logic
  
  return (
    <div>
      {/* Presentation mixed with logic */}
    </div>
  );
}
```

**Good Example:**

```jsx
// ✅ Business logic in custom hook
function useAgentSession(mode) {
  const [session, setSession] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(false);
  
  const initialize = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/sessions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode })
      });
      const data = await response.json();
      setSession(data.session);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };
  
  const sendMessage = async (content) => {
    const response = await fetch(`/api/sessions/${session.id}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content })
    });
    const data = await response.json();
    setMessages(m => [...m, data.message]);
  };
  
  return { session, messages, loading, initialize, sendMessage };
}

// ✅ Component is pure presentation
function AgentPanel({ mode }) {
  const { session, messages, loading, initialize, sendMessage } = useAgentSession(mode);
  
  return (
    <div className="agent-panel">
      {!session ? (
        <button onClick={initialize} disabled={loading}>
          Initialize Session
        </button>
      ) : (
        <>
          <MessageList messages={messages} />
          <MessageInput onSend={sendMessage} />
        </>
      )}
    </div>
  );
}
```

**Why**: Hooks separate concerns, make logic reusable across components, and simplify testing.

---

### [ARCH][!CONTAINER-PRESENTATIONAL]

**Rule**: Separate container components (logic, state, data fetching) from presentational components (pure, props-driven rendering).

**Bad Example:**

```jsx
// ❌ Mixed concerns
function FileList() {
  const [files, setFiles] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(null);
  
  useEffect(() => {
    fetch('/api/files')
      .then(r => r.json())
      .then(data => setFiles(data.files));
  }, []);
  
  return (
    <div className="file-list">
      {loading && <Spinner />}
      {files.map(file => (
        <div 
          key={file.id}
          className={selected === file.id ? 'selected' : ''}
          onClick={() => setSelected(file.id)}
        >
          {file.icon} {file.name}
        </div>
      ))}
    </div>
  );
}
```

**Good Example:**

```jsx
// ✅ Container: handles logic and data
function FileListContainer() {
  const [files, setFiles] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(null);
  
  useEffect(() => {
    setLoading(true);
    fetch('/api/files')
      .then(r => r.json())
      .then(data => {
        setFiles(data.files);
        setLoading(false);
      });
  }, []);
  
  return (
    <FileList
      files={files}
      loading={loading}
      selectedId={selected}
      onSelect={setSelected}
    />
  );
}

// ✅ Presentational: pure rendering
function FileList({ files, loading, selectedId, onSelect }) {
  if (loading) return <Spinner />;
  
  return (
    <div className="file-list">
      {files.map(file => (
        <FileItem
          key={file.id}
          file={file}
          selected={file.id === selectedId}
          onSelect={() => onSelect(file.id)}
        />
      ))}
    </div>
  );
}

function FileItem({ file, selected, onSelect }) {
  return (
    <div 
      className={`file-item ${selected ? 'selected' : ''}`}
      onClick={onSelect}
    >
      <span className="icon">{file.icon}</span>
      <span className="name">{file.name}</span>
    </div>
  );
}
```

**Why**: Presentational components are easy to test (just props), reusable, and can be in a component library.

---

## Component Composition Pattern

```
UI Component Architecture
│
├── Orchestrator Components (coordinate)
│   ├── Minimal local state (UI only)
│   ├── Aggregate global state via hooks
│   ├── Aggregate actions/callbacks
│   ├── Compose child components
│   └── Size: ~50-150 lines
│
│   Example responsibilities:
│   ├── Track: activeTab, modalOpen, dropdownExpanded
│   ├── Delegate: business logic to hooks
│   └── Compose: layout, panels, modals

├── Layout Components (structure, no logic)
│   │
│   ├── IDELayout
│   │   ├── Props: {leftPanel, middlePanel, rightPanel}
│   │   ├── Responsibilities: Grid layout, responsive design
│   │   └── Children:
│   │       ├── leftPanel (slot)
│   │       ├── middlePanel (slot)
│   │       └── rightPanel (slot)
│   │
│   ├── Panel
│   │   ├── Props: {title, icon, children, className}
│   │   ├── Responsibilities: Consistent panel styling
│   │   └── Children:
│   │       ├── <PanelHeader title={title} icon={icon} />
│   │       └── <PanelContent>{children}</PanelContent>
│   │
│   └── TabBar
│       ├── Props: {activeTab, onTabChange, tabs}
│       └── Responsibilities: Tab navigation UI

├── Container Components (data + logic)
│   │
│   ├── FileTreeBrowserContainer
│   │   ├── Responsibilities:
│   │   │   ├── Fetch file tree from API
│   │   │   ├── Track selected file
│   │   │   ├── Handle file selection events
│   │   │   └── Pass data to presentational component
│   │   │
│   │   ├── State:
│   │   │   ├── files: Array<FileNode>
│   │   │   ├── loading: boolean
│   │   │   ├── error: string | null
│   │   │   └── selectedId: string | null
│   │   │
│   │   ├── Effects:
│   │   │   └── useEffect(() => fetchFileTree(), [projectPath])
│   │   │
│   │   └── Renders: <FileTreeBrowser data={...} handlers={...} />
│   │
│   └── AgentPanelContainer
│       ├── Responsibilities:
│       │   ├── Manage agent session lifecycle
│       │   ├── Handle chat message flow
│       │   └── Coordinate tool execution
│       │
│       ├── Hooks:
│       │   ├── useAgentSession(mode)
│       │   └── useToolExecution()
│       │
│       └── Renders: <AgentPanel session={...} handlers={...} />

├── Presentational Components (pure rendering)
│   │
│   ├── FileTreeBrowser
│   │   ├── Props: {files, selectedId, onSelect, loading, error}
│   │   ├── Responsibilities: Render file tree UI
│   │   ├── No state, no effects, no API calls
│   │   └── Children:
│   │       ├── {loading && <Spinner />}
│   │       ├── {error && <ErrorMessage message={error} />}
│   │       └── {files.map(file => <FileItem ... />)}
│   │
│   ├── FileItem
│   │   ├── Props: {file, selected, onSelect}
│   │   ├── Responsibilities: Render single file/folder
│   │   └── ~10 lines (pure presentation)
│   │
│   ├── AgentPanel
│   │   ├── Props: {session, messages, onSend, loading}
│   │   ├── Responsibilities: Render agent UI
│   │   └── Children:
│   │       ├── {!session && <InitializeButton />}
│   │       ├── {session && <MessageList messages={messages} />}
│   │       └── {session && <MessageInput onSend={onSend} />}
│   │
│   ├── CodeEditor
│   │   ├── Props: {filePath, content, readOnly, onChange}
│   │   ├── Responsibilities: Monaco editor wrapper
│   │   └── Pure presentation (Monaco handles internals)
│   │
│   └── Button
│       ├── Props: {onClick, disabled, children, variant}
│       ├── Responsibilities: Consistent button styling
│       └── Reusable across entire app

├── Custom Hooks (business logic)
│   │
│   ├── useIDEState()
│   │   ├── Aggregates Zustand store selectors
│   │   └── Returns: {session, agent, project, file, approval}
│   │
│   ├── useIDEActions()
│   │   ├── Aggregates Zustand store actions
│   │   └── Returns: {session: {...}, agent: {...}, project: {...}}
│   │
│   ├── useAgentSession(mode)
│   │   ├── Manages session lifecycle
│   │   ├── State: session, messages, loading
│   │   ├── Actions: initialize(), sendMessage()
│   │   └── Effects: Auto-cleanup on unmount
│   │
│   ├── useToolExecution()
│   │   ├── Executes tools via API
│   │   ├── Tracks execution state
│   │   └── Returns: {execute, loading, result, error}
│   │
│   └── useFileTree(projectPath)
│       ├── Fetches and caches file tree
│       ├── Auto-refetches on path change
│       └── Returns: {tree, loading, error, refetch}

└── Modal Components (behavior components)
    │
    ├── ModalManager
    │   ├── Props: {approval, config, preferences, handlers}
    │   ├── Responsibilities: Coordinate all modals
    │   └── Children (conditional):
    │       ├── {approval.visible && <ApprovalModal ... />}
    │       ├── {config.visible && <ConfigModal ... />}
    │       └── {preferences.visible && <PreferencesModal ... />}
    │
    ├── ApprovalModal
    │   ├── Props: {visible, data, loading, onApprove, onReject, onClose}
    │   ├── Responsibilities: Display approval request UI
    │   └── Children:
    │       ├── <ModalOverlay />
    │       ├── <ModalContent>
    │       │   ├── <ApprovalDetails data={data} />
    │       │   └── <ApprovalActions onApprove={...} onReject={...} />
    │       └── </ModalContent>
    │
    └── ConfigModal
        ├── Props: {visible, onClose}
        ├── Container: Fetches config data
        └── Renders: <ConfigForm config={...} onSave={...} />

Data Flow Example:
User clicks file in FileTreeBrowser
│
├── FileItem.onClick() (presentational)
│   └── calls: onSelect(file.id) (prop from parent)
│
├── FileTreeBrowser.onSelect(id) (presentational)
│   └── calls: onSelect(id) (prop from container)
│
├── FileTreeBrowserContainer.handleSelect(id) (container)
│   ├── setSelectedId(id)
│   └── calls: actions.file.select(id) (prop from orchestrator)
│
├── UnifiedIDE.actions.file.select(id) (orchestrator)
│   └── calls: Zustand action (global state)
│
└── useAgentStore.selectFile(id) (global state)
    ├── Updates: state.selectedFileId = id
    ├── Triggers: API call to fetch file content
    └── Re-renders: All components using selectedFile selector

Component Size Guidelines:
├── Orchestrator: <150 lines
├── Container: <100 lines
├── Presentational: <80 lines
├── Layout: <60 lines
└── Leaf components: <30 lines
```

## Patterns

### Pattern: Component Hierarchy

```
UnifiedIDE (Orchestrator)
├── ModalManager (Behavior)
│   ├── ApprovalModal
│   ├── ConfigModal
│   └── PreferencesModal
├── IDEHeader (Presentation)
│   ├── SessionBadge
│   ├── ProjectPathInput
│   └── ActionButtons
├── PersistentContextBar (Feature)
└── IDELayout (Structure)
    ├── LeftPanel
    │   └── FileTreeBrowser
    ├── MiddlePanel
    │   ├── CodeEditor
    │   └── MemoryInspector
    └── RightPanel
        ├── AgentControls
        ├── TabBar
        └── TabContent
```

---

### Pattern: Custom Hooks for State & Actions

```jsx
// State aggregation hook
function useIDEState() {
  const sessionId = useAgentStore(state => state.currentSessionId);
  const mode = useAgentStore(state => state.mode);
  const projectPath = useAgentStore(state => state.projectPath);
  const selectedFile = useAgentStore(state => state.selectedFile);
  const approval = useAgentStore(state => state.pendingApproval);
  
  return {
    session: { id: sessionId },
    agent: { mode },
    project: { path: projectPath },
    file: { selected: selectedFile },
    approval: { pending: approval }
  };
}

// Actions aggregation hook
function useIDEActions() {
  const initializeSession = useAgentStore(state => state.initializeSession);
  const setMode = useAgentStore(state => state.setMode);
  const setProjectPath = useAgentStore(state => state.setProjectPath);
  const loadFileTree = useAgentStore(state => state.loadFileTree);
  const readFile = useAgentStore(state => state.readFile);
  
  return {
    session: { initialize: () => initializeSession(mode) },
    agent: { changeMode: setMode },
    project: { setPath: setProjectPath, loadFileTree },
    file: { select: readFile }
  };
}

// Usage in component
function UnifiedIDE() {
  const state = useIDEState();
  const actions = useIDEActions();
  
  return (
    <IDEHeader
      sessionId={state.session.id}
      onInitialize={actions.session.initialize}
      // ...
    />
  );
}
```

---

## Checklist

When refactoring to composition patterns:

- [ ] Components < 100 lines (orchestrators < 150 lines)
- [ ] Each component has ONE clear responsibility
- [ ] Business logic extracted to custom hooks
- [ ] Container components handle state/data
- [ ] Presentational components are pure (props only)
- [ ] Props flow down, events flow up
- [ ] Composition used over inheritance
- [ ] No direct DOM manipulation (use React refs if needed)
- [ ] Components testable in isolation
- [ ] State aggregation hooks reduce store coupling
- [ ] Modal/dialog management centralized

---

## Summary

**Key Principles:**

1. **Single Responsibility** - one component, one purpose
2. **Composition** - build complex from simple
3. **Props down, events up** - one-way data flow
4. **Custom hooks** - extract business logic
5. **Container/Presentational** - separate concerns

**Benefits:**

- Small, testable components
- Clear responsibilities
- Easy to understand and modify
- Reusable across features
- Better performance (smaller re-render boundaries)

**When to Use:**

- Building complex UIs
- Components > 100 lines
- Multiple responsibilities in one component
- State management tightly coupled
- Components difficult to test

