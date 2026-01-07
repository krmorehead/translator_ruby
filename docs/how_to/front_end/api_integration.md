---
description: Frontend API client patterns and integration
globs: app/frontend/api/**/*.ts
alwaysApply: false
---

# API Client Patterns

**Tags**: [coding, front_end]  
**Applies To**: Frontend API integration  
**Date**: 2026-01-05

## Overview

API client patterns for transforming API responses to domain objects and handling SSE streams.

## API Integration Flow Tree

```
API Integration Architecture
│
├── API Request Flow
│   ├── Domain Object (JavaScript)
│   │   └── session.toJSON()
│   │       → {id: "123", agent_type: "daedalus", ...}
│   │
│   ├── Serialize for API
│   │   └── JSON.stringify(session.toJSON())
│   │
│   ├── HTTP Request
│   │   └── fetch('/api/sessions', {
│   │         method: 'POST',
│   │         body: JSON.stringify(...)
│   │       })
│   │
│   └── Response
│       → Backend processes request
│
├── API Response Flow
│   ├── HTTP Response
│   │   └── {status: 200, body: '{"session": {...}}'}
│   │
│   ├── Parse JSON
│   │   └── const json = await response.json()
│   │       → {session: {id: "123", agent_type: "daedalus"}}
│   │
│   ├── Deserialize to Domain Object
│   │   └── const session = DomainEntity.fromJSON(json.session)
│   │       → DomainEntity instance (frozen, validated)
│   │
│   └── Use in Application
│       ├── session.id
│       ├── session.isActive()
│       └── Type-safe methods available
│
├── SSE Streaming Flow
│   ├── Open EventSource
│   │   └── const es = new EventSource('/api/executions/123/stream')
│   │
│   ├── Listen for Events
│   │   ├── es.addEventListener('connected', ...)
│   │   ├── es.addEventListener('progress', ...)
│   │   └── es.addEventListener('error', ...)
│   │
│   ├── Handle Progress Events
│   │   └── onProgress(event) {
│   │         const data = JSON.parse(event.data);
│   │         updateUI(data);
│   │       }
│   │
│   ├── Detect Terminal Events
│   │   └── if (['completed', 'failed'].includes(data.event_type)) {
│   │         es.close();
│   │       }
│   │
│   └── Cleanup on Unmount
│       └── useEffect(() => {
│             const es = subscribe(...);
│             return () => es.close();
│           }, []);
│
└── Error Handling Flow
    ├── HTTP Errors
    │   ├── !response.ok → throw Error
    │   └── Catch in calling code
    │
    ├── Network Errors
    │   ├── fetch() rejects
    │   └── Show error UI
    │
    └── Validation Errors
        ├── fromJSON() throws
        └── Catch and display
```

---

## Rules

### [API][!DESERIALIZE-TO-DOMAIN-OBJECTS]

**Rule**: Deserialize API responses to domain objects, not raw JSON.

**Good Example:**

```javascript
class EntityAPI {
  async createSession(agentType) {
    const response = await fetch('/api/sessions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ agent_type: agentType })
    });
    
    const json = await response.json();
    
    // Transform to domain object
    return DomainEntity.fromJSON(json.session);
  }
}

// Usage
const session = await api.createSession('daedalus');
console.log(session.id);  // Domain object, not raw JSON
console.log(session.isActive());  // Method available
```

---

### [API][!FROM-JSON-STATIC-METHOD]

**Rule**: Use static fromJSON methods for deserialization.

**Good Example:**

```javascript
export class DomainEntity {
  constructor({ entityType, status, timestamp }) {
    this._id = crypto.randomUUID();
    this._entityType = entityType;
    this._status = status;
    this._timestamp = new Date(timestamp);
  }
  
  get id() { return this._id; }
  get entityType() { return this._entityType; }
  
  isActive() {
    return this._status === 'active';
  }
  
  static fromJSON(json) {
    return new DomainEntity({
      entityType: json.entity_type,
      status: json.status,
      timestamp: json.timestamp
    });
  }
  
  toJSON() {
    return {
      id: this._id,
      entity_type: this._entityType,
      status: this._status,
      timestamp: this._timestamp.toISOString()
    };
  }
}
```

---

### [API][!TO-JSON-BEFORE-SENDING]

**Rule**: Serialize objects with toJSON() before sending to API.

**Good Example:**

```javascript
async function updateEntity(entity) {
  const response = await fetch(`/api/entities/${entity.id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(entity.toJSON())  // Serialize first
  });
  
  const json = await response.json();
  return DomainEntity.fromJSON(json.entity);
}
```

---

### [API][!EVENTSOURCE-FOR-STREAMING]

**Rule**: Use EventSource for SSE streaming, not polling.

**Good Example:**

```javascript
export function subscribeToWorkerProgress({
  streamUrl,
  onEvent,
  onComplete,
  onError
}) {
  const eventSource = new EventSource(streamUrl);

  eventSource.addEventListener('connected', (e) => {
    console.log('Stream connected:', JSON.parse(e.data));
  });

  eventSource.addEventListener('progress', (e) => {
    const data = JSON.parse(e.data);
    
    // Terminal events
    if (['completed', 'failed', 'cancelled'].includes(data.event_type)) {
      onComplete?.(data);
      eventSource.close();
      return;
    }
    
    // Progress events
    onEvent(data);
  });

  eventSource.addEventListener('error', (e) => {
    const data = e.data ? JSON.parse(e.data) : { message: 'Unknown error' };
    onError?.(data);
    eventSource.close();
  });

  return eventSource;
}

// Usage
const eventSource = subscribeToWorkerProgress({
  streamUrl: `/api/executions/${id}/stream`,
  onEvent: (event) => updateUI(event),
  onComplete: (data) => showSuccess(data),
  onError: (error) => showError(error)
});

// Cleanup
onCleanup(() => eventSource.close());
```

---

## Pattern: API Client

```javascript
class EntityAPI {
  constructor(baseUrl = '/api') {
    this._id = crypto.randomUUID();
    this.baseUrl = baseUrl;
  }
  
  async createSession(agentType) {
    const response = await this.post('/sessions', {
      agent_type: agentType
    });
    return DomainEntity.fromJSON(response.session);
  }
  
  async sendMessage(sessionId, content) {
    const response = await this.post(`/sessions/${sessionId}/messages`, {
      content
    });
    return Message.fromJSON(response.message);
  }
  
  subscribeToProgress(executionId, handlers) {
    return subscribeToWorkerProgress({
      streamUrl: `${this.baseUrl}/executions/${executionId}/stream`,
      ...handlers
    });
  }
  
  async post(path, data) {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    
    if (!response.ok) {
      throw new Error(`API error: ${response.statusText}`);
    }
    
    return response.json();
  }
}

export const agentAPI = new EntityAPI();
```

---

## Summary

**Key Principles:**

1. Deserialize to domain objects
2. Static fromJSON methods
3. toJSON() before sending
4. EventSource for SSE
5. Centralized API client

**Benefits:**

- Type-safe API interactions
- Domain objects everywhere
- Real-time updates via SSE
- Easy error handling
- Consistent API access

