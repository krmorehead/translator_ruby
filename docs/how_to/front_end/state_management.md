---
description: Zustand state management patterns for React applications
globs: app/frontend/stores/**/*.ts
alwaysApply: false
---

# State Management Patterns

**Tags**: [coding, front_end]  
**Applies To**: React state management (Zustand as reference)  
**Date**: 2026-01-05

## Overview

State management patterns using Zustand for global state and local state for UI concerns.

## State Management Tree

```
State Architecture
│
├── Global State (Zustand)
│   ├── Application data
│   ├── Shared across components
│   ├── Persists across navigation
│   └── Examples:
│       ├── currentSessionId
│       ├── mode (daedalus/sisyphus)
│       ├── projectPath
│       └── selectedFileId
│
├── Local State (useState)
│   ├── UI-only concerns
│   ├── Component-specific
│   ├── Doesn't persist
│   └── Examples:
│       ├── activeTab
│       ├── modalOpen
│       ├── inputValue
│       └── dropdownExpanded
│
├── Actions (grouped by domain)
│   ├── session:
│   │   ├── initialize()
│   │   └── destroy()
│   ├── agent:
│   │   └── changeMode()
│   ├── project:
│   │   ├── setPath()
│   │   └── loadFileTree()
│   └── file:
│       └── select()
│
└── Data Flow
    Component → Action → Store Update → Selector → Re-render
```

---

## Rules

### [STATE][!ZUSTAND-GLOBAL]

**Rule**: Use Zustand for global application state.

**Good Example:**

```javascript
import { create } from 'zustand';

const useAgentStore = create((set) => ({
  // State
  currentSessionId: null,
  mode: 'daedalus',
  projectPath: '',
  
  // Actions
  initializeSession: (mode) => {
    // Async logic
    fetch('/api/sessions', {
      method: 'POST',
      body: JSON.stringify({ mode })
    }).then(r => r.json()).then(data => {
      set({ currentSessionId: data.session.id });
    });
  },
  
  setMode: (mode) => set({ mode }),
  setProjectPath: (path) => set({ projectPath: path })
}));
```

---

### [STATE][!LOCAL-UI-STATE]

**Rule**: Keep UI-only state local to components.

**Good Example:**

```jsx
function Component() {
  // ✅ UI state stays local
  const [activeTab, setActiveTab] = useState("chat");
  const [modalOpen, setModalOpen] = useState(false);
  
  // ✅ App state from store
  const sessionId = useAgentStore(state => state.currentSessionId);
  
  return <div>...</div>;
}
```

---

### [STATE][!GROUP-ACTIONS-BY-DOMAIN]

**Rule**: Group actions by domain (session, agent, project).

**Good Example:**

```javascript
const useIDEActions = () => {
  return {
    session: {
      initialize: useAgentStore(state => state.initializeSession),
      destroy: useAgentStore(state => state.destroySession)
    },
    agent: {
      changeMode: useAgentStore(state => state.setMode)
    },
    project: {
      setPath: useAgentStore(state => state.setProjectPath),
      loadFileTree: useAgentStore(state => state.loadFileTree)
    }
  };
};
```

---

### [STATE][!NO-MUTATION]

**Rule**: Always return new state objects, never mutate.

**Good Example:**

```javascript
const useStore = create((set) => ({
  items: [],
  
  // ✅ Update without mutation
  addItem: (item) => set(state => ({
    items: [...state.items, item]
  })),
  
  // ❌ Mutation
  // addItem: (item) => state.items.push(item)
}));
```

---

## Summary

**Key Principles:**

1. Zustand for global state
2. Local state for UI concerns
3. Group actions by domain
4. Updates without mutation

**Benefits:**

- Clear state ownership
- Easy testing
- Predictable updates
- No prop drilling

