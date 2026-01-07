---
description: React component design patterns and composition
globs: app/frontend/components/**/*.tsx
alwaysApply: false
---

# React Component Design

**Tags**: [coding, design, front_end]  
**Applies To**: React applications  
**Date**: 2026-01-05

## Overview

React component design patterns emphasizing single responsibility, composition, and separation of presentation from business logic.

## Component Pattern Tree

```
React Component Patterns
│
├── Container (logic + data)
│   ├── State management
│   ├── API calls
│   ├── Event handlers
│   └── Renders → Presentational component
│
├── Presentational (pure rendering)
│   ├── Receives data via props
│   ├── Renders UI
│   ├── Calls event handlers via props
│   └── No state, no effects, no API
│
├── Custom Hooks (extracted logic)
│   ├── Business logic
│   ├── Side effects
│   ├── State management
│   └── Returns: {state, actions}
│
└── Data Flow
    User Event → Presentational → Container → Hook → API → State Update → Re-render
```

---

## Rules

### [COMP][!SINGLE-RESPONSIBILITY]

**Rule**: One component, one responsibility. Split if > 100 lines.

**Good Example:**

```jsx
// ✅ Small, focused component
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

---

### [COMP][!PROPS-DOWN-EVENTS-UP]

**Rule**: Data flows down via props, events flow up via callbacks.

**Good Example:**

```jsx
function Parent() {
  const [count, setCount] = useState(0);
  
  return (
    <Child 
      count={count}  // Data down
      onIncrement={() => setCount(c => c + 1)}  // Events up
    />
  );
}
```

---

### [COMP][!EXTRACT-HOOKS]

**Rule**: Extract business logic to custom hooks.

**Good Example:**

```jsx
// Hook for business logic
function useAgentSession(mode) {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const initialize = async () => {
    setLoading(true);
    const response = await fetch('/api/sessions', {
      method: 'POST',
      body: JSON.stringify({ mode })
    });
    const data = await response.json();
    setSession(data.session);
    setLoading(false);
  };
  
  return { session, loading, initialize };
}

// Component is pure presentation
function AgentPanel({ mode }) {
  const { session, loading, initialize } = useAgentSession(mode);
  
  return (
    <div>
      {!session && (
        <button onClick={initialize} disabled={loading}>
          Initialize
        </button>
      )}
      {session && <ChatInterface session={session} />}
    </div>
  );
}
```

---

### [COMP][!CONTAINER-PRESENTATIONAL]

**Rule**: Separate container (logic) from presentational (rendering) components.

**Good Example:**

```jsx
// Container: handles logic
function FileListContainer() {
  const [files, setFiles] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  
  useEffect(() => {
    fetch('/api/files').then(r => r.json()).then(setFiles);
  }, []);
  
  return (
    <FileList
      files={files}
      selectedId={selectedId}
      onSelect={setSelectedId}
    />
  );
}

// Presentational: pure rendering
function FileList({ files, selectedId, onSelect }) {
  return (
    <div>
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
```

---

## Summary

**Key Principles:**

1. Single responsibility per component
2. Props down, events up
3. Extract business logic to hooks
4. Container/Presentational separation
5. Components < 100 lines

**Benefits:**

- Testable components
- Clear responsibilities
- Reusable logic
- Easy to understand

