---
description: Frontend testing patterns with Vitest and Playwright
globs: "**/*.test.{ts,tsx}"
alwaysApply: false
---

# Frontend Testing Patterns

**Tags**: [testing, front_end]  
**Applies To**: React testing with TypeScript (Vitest + Playwright)  
**Date**: 2026-01-06

## Overview

Frontend testing with strong TypeScript typing, speed profiles, factories for domain objects, beforeEach for reusable setup, and input/output focused testing. No mocks, real backend integration.

## Frontend Test Organization Tree

```
Frontend Test Suite (TypeScript)
│
├── Unit Tests (Vitest + React Testing Library)
│   │
│   ├── src/models/__tests__/
│   │   ├── DomainEntity.test.ts
│   │   │   import { describe, test, expect, beforeEach } from 'vitest'
│   │   │   import { EntityFactory } from '../factories'
│   │   │   
│   │   │   describe('DomainEntity', () => {
│   │   │     let entity: DomainEntity
│   │   │     
│   │   │     beforeEach(() => {
│   │   │       entity = EntityFactory.create({ status: 'pending' })
│   │   │     })
│   │   │     
│   │   │     test('validates constructor params', () => {
│   │   │       expect(() => new DomainEntity({ status: 'invalid' }))
│   │   │         .toThrow('Invalid status')
│   │   │     })
│   │   │     
│   │   │     test('isPending returns correct output', () => {
│   │   │       // Input → Output testing
│   │   │       const result: boolean = entity.isPending()
│   │   │       expect(result).toBe(true)
│   │   │     })
│   │   │   })
│   │   │
│   │   └── Session.test.ts
│   │       ├── Typed factories
│   │       ├── beforeEach for shared setup
│   │       └── Input/output assertions
│   │
│   └── src/components/__tests__/
│       ├── DataBrowser.test.tsx
│       │   import { describe, test, expect, beforeEach } from 'vitest'
│       │   import { render, screen } from '@testing-library/react'
│       │   import { DataFactory } from '../factories'
│       │   
│       │   describe('DataBrowser', () => {
│       │     let mockData: DataItem[]
│       │     
│       │     beforeEach(() => {
│       │       mockData = [
│       │         DataFactory.create({ id: '1', name: 'Item 1' }),
│       │         DataFactory.create({ id: '2', name: 'Item 2' })
│       │       ]
│       │     })
│       │     
│       │     test('renders data list output', () => {
│       │       render(<DataBrowser data={mockData} />)
│       │       
│       │       // Assert output rendered
│       │       expect(screen.getByText('Item 1')).toBeInTheDocument()
│       │       expect(screen.getByText('Item 2')).toBeInTheDocument()
│       │     })
│       │   })
│       │
│       └── EntityPanel.test.tsx
│           └── Typed props, beforeEach setup
│
└── E2E Tests (Playwright + TypeScript)
    │
    ├── e2e/base-test.ts
    │   import { test as base, expect } from '@playwright/test'
    │   
    │   type SpeedTest = {
    │     (title: string, testFn: TestFn): void
    │   }
    │   
    │   export const fast: SpeedTest = (title, testFn) => {
    │     base(title, async ({ page }) => {
    │       base.setTimeout(5000)
    │       await testFn({ page })
    │     })
    │   }
    │   
    │   export const medium: SpeedTest = (title, testFn) => {
    │     base(title, async ({ page }) => {
    │       base.setTimeout(15000)
    │       await testFn({ page })
    │     })
    │   }
    │   
    │   export const slow: SpeedTest = (title, testFn) => {
    │     base(title, async ({ page }) => {
    │       base.setTimeout(30000)
    │       await testFn({ page })
    │     })
    │   }
    │
    ├── e2e/unified-ide-basic.spec.ts
    │   import { fast, expect } from './base-test'
    │   import type { Page } from '@playwright/test'
    │   
    │   // Fast: UI only
    │   fast('renders IDE layout', async ({ page }: { page: Page }) => {
    │     await page.goto('/ide')
    │     
    │     const layout = page.locator('.ide-layout')
    │     await expect(layout).toBeVisible()
    │   })
    │
    ├── e2e/unified-ide-file-browsing.spec.ts
    │   import { medium, expect } from './base-test'
    │   import type { Page } from '@playwright/test'
    │   
    │   // Medium: API integration
    │   medium('loads project files', async ({ page }: { page: Page }) => {
    │     await page.goto('/ide')
    │     await page.locator('#project-path').fill('/test/project')
    │     await page.locator('button[data-action="load"]').click()
    │     
    │     // Wait for output
    │     const fileTree = page.locator('.file-tree')
    │     await expect(fileTree).toBeVisible()
    │   })
    │
    └── e2e/unified-ide-daedalus-llm.spec.ts
        import { slow, expect } from './base-test'
        import type { Page } from '@playwright/test'
        
        // Slow: LLM integration
        slow('sends message with LLM', async ({ page }: { page: Page }) => {
          await page.goto('/agent')
          
          // Input
          await page.locator('#message').fill('Hello')
          await page.locator('button[data-action="send"]').click()
          
          // Assert output appears
          const response = page.locator('.llm-response').first()
          await expect(response).toBeVisible()
          await expect(response).toContainText(/\w+/) // Has content
        })

Factories (TypeScript):
src/factories/EntityFactory.ts
├── import type { EntityData, Entity } from '../models'
│
├── export class EntityFactory {
│     static create(overrides: Partial<EntityData> = {}): Entity {
│       const defaults: EntityData = {
│         id: crypto.randomUUID(),
│         status: 'pending',
│         createdAt: new Date()
│       }
│       
│       return new Entity({ ...defaults, ...overrides })
│     }
│     
│     static createActive(): Entity {
│       return this.create({ status: 'active' })
│     }
│   }
│
└── Type-safe factory with overrides

Test Pattern: Input → Output
├── Arrange: Use beforeEach + factories
│   beforeEach(() => {
│     entity = EntityFactory.create({ status: 'pending' })
│   })
│
├── Act: Call method with typed input
│   const result: ResultType = entity.process(input)
│
└── Assert: Verify typed output
    expect(result).toBeInstanceOf(ExpectedClass)
    expect(result.property).toBe(expectedValue)
```

---

## Rules

### [TEST-FE][!TYPESCRIPT-STRICT]

**Rule**: All test files must use TypeScript strict mode with explicit types.

**Good Example:**

```typescript
import { describe, test, expect, beforeEach } from 'vitest'
import type { Entity, EntityStatus } from '../models/Entity'
import { EntityFactory } from '../factories/EntityFactory'

describe('Entity', () => {
  let entity: Entity
  let status: EntityStatus
  
  beforeEach(() => {
    status = 'pending'
    entity = EntityFactory.create({ status })
  })
  
  test('validates status input', () => {
    // Test invalid input
    expect(() => {
      new Entity({ status: 'invalid' as EntityStatus })
    }).toThrow('Invalid status')
  })
  
  test('isPending returns boolean output', () => {
    // Input → Output
    const result: boolean = entity.isPending()
    
    // Assert output type and value
    expect(typeof result).toBe('boolean')
    expect(result).toBe(true)
  })
  
  test('activate mutates status output', () => {
    // Input
    const activatedBy: string = 'user@example.com'
    
    // Execute
    entity.activate(activatedBy)
    
    // Assert output
    expect(entity.status).toBe('active')
    expect(entity.activatedBy).toBe(activatedBy)
  })
})
```

**Why**: TypeScript strict mode catches type errors at compile time.

---

### [TEST-FE][!TYPED-FACTORIES]

**Rule**: All factories must return strongly typed objects.

**Good Example:**

```typescript
import type { Entity, EntityData } from '../models/Entity'

interface EntityFactoryOptions {
  readonly status?: EntityStatus
  readonly metadata?: Record<string, string>
}

export class EntityFactory {
  static create(overrides: Partial<EntityData> = {}): Entity {
    const defaults: EntityData = {
      id: crypto.randomUUID(),
      status: 'pending' as EntityStatus,
      metadata: {},
      createdAt: new Date()
    }
    
    return new Entity({ ...defaults, ...overrides })
  }
  
  static createWithStatus(status: EntityStatus): Entity {
    return this.create({ status })
  }
  
  static createBatch(count: number): Entity[] {
    return Array.from({ length: count }, (_, i) =>
      this.create({ metadata: { index: i.toString() } })
    )
  }
}

// Usage in tests
describe('EntityList', () => {
  let entities: Entity[]
  
  beforeEach(() => {
    entities = EntityFactory.createBatch(3)
  })
  
  test('processes multiple entities', () => {
    const processor = new EntityProcessor()
    
    // Input: Array of entities
    const results: ProcessResult[] = processor.processAll(entities)
    
    // Assert output
    expect(results).toHaveLength(3)
    expect(results.every(r => r instanceof ProcessResult)).toBe(true)
  })
})
```

**Why**: Typed factories ensure test data matches production types.

---

### [TEST-FE][!BEFORE-EACH-FOR-REUSE]

**Rule**: Use `beforeEach()` for reusable setup. Keep it focused and fast.

**Good Example:**

```typescript
import { describe, test, expect, beforeEach, afterEach } from 'vitest'
import { EntityFactory } from '../factories/EntityFactory'
import type { Entity } from '../models/Entity'

describe('EntityService', () => {
  let service: EntityService
  let entity: Entity
  
  // Shared setup - runs before each test
  beforeEach(() => {
    service = new EntityService()
    entity = EntityFactory.create({ status: 'pending' })
  })
  
  // Cleanup - runs after each test
  afterEach(() => {
    // Clean up if needed
    service.cleanup()
  })
  
  test('processes entity successfully', () => {
    // service and entity already set up
    const result = service.process(entity)
    
    expect(result.success).toBe(true)
  })
  
  test('handles error gracefully', () => {
    const invalidEntity = EntityFactory.create({ status: 'invalid' as any })
    
    expect(() => service.process(invalidEntity)).toThrow()
  })
  
  describe('with active entity', () => {
    // Nested context with override
    beforeEach(() => {
      entity = EntityFactory.create({ status: 'active' })
    })
    
    test('skips activation step', () => {
      const result = service.process(entity)
      
      expect(result.activationSkipped).toBe(true)
    })
  })
})
```

**Why**: `beforeEach()` keeps tests isolated while sharing setup code.

---

### [TEST-FE][!INPUT-OUTPUT-ONLY]

**Rule**: Test public interface only. Never test internal state or private methods.

**Bad Example:**

```typescript
// ❌ Testing internals
test('sets internal flag', () => {
  service.process(input)
  
  // ❌ Don't access private state
  expect((service as any)._internalFlag).toBe(true)
})

// ❌ Testing private methods
test('private helper works', () => {
  expect((service as any)._privateHelper('test')).toBe('result')
})
```

**Good Example:**

```typescript
// ✅ Test public interface only
describe('EntityProcessor', () => {
  let processor: EntityProcessor
  let entity: Entity
  
  beforeEach(() => {
    processor = new EntityProcessor()
    entity = EntityFactory.create({ status: 'pending' })
  })
  
  test('process transforms input to expected output', () => {
    // Input
    const input: ProcessInput = { entity, options: { validate: true } }
    
    // Execute
    const result: ProcessResult = processor.process(input)
    
    // Assert output
    expect(result).toBeInstanceOf(ProcessResult)
    expect(result.success).toBe(true)
    expect(result.entity.status).toBe('processed')
  })
  
  test('process throws error for invalid input', () => {
    const invalidInput: ProcessInput = { 
      entity: null as any, 
      options: { validate: true } 
    }
    
    expect(() => processor.process(invalidInput)).toThrow('Entity required')
  })
})
```

**Why**: Testing public interface avoids coupling to implementation details.

---

### [TEST-FE][!SPEED-PROFILE-E2E]

**Rule**: E2E tests use typed fast/medium/slow functions from base-test.

**Good Example:**

```typescript
import { fast, medium, slow, expect } from './base-test'
import type { Page } from '@playwright/test'

// Fast: UI only, no network
fast('renders form fields', async ({ page }: { page: Page }): Promise<void> => {
  await page.goto('/agent')
  
  const goalInput = page.locator('#goal')
  await expect(goalInput).toBeVisible()
  await expect(goalInput).toHaveAttribute('type', 'text')
})

// Medium: API calls, no LLM
medium('loads config from API', async ({ page }: { page: Page }): Promise<void> => {
  await page.goto('/agent')
  
  const configButton = page.locator('button[data-action="load-config"]')
  await configButton.click()
  
  const configPanel = page.locator('.config-panel')
  await expect(configPanel).toBeVisible()
  
  const modelName = page.locator('.model-name')
  await expect(modelName).toHaveText(/llama|gpt/)
})

// Slow: Real LLM integration
slow('generates plan with LLM', async ({ page }: { page: Page }): Promise<void> => {
  await page.goto('/agent')
  
  // Input
  await page.locator('#goal').fill('Add health check endpoint')
  await page.locator('button[data-action="generate"]').click()
  
  // Assert output appears
  const planResult = page.locator('.plan-result-section')
  await expect(planResult).toBeVisible()
  
  const milestones = page.locator('.milestone')
  await expect(milestones).toHaveCount.greaterThan(0)
})
```

**Why**: Typed test functions provide type safety and consistent timeouts.

---

### [TEST-FE][!WAIT-FOR-CONDITIONS]

**Rule**: Never use explicit timeouts or arbitrary waits. Tests should wait for actual conditions, not time periods. Speed profile controls necessary timeouts.

**Bad Example:**

```typescript
// ❌ Explicit timeout in assertion
await expect(page.locator('.result')).toBeVisible({ timeout: 30000 })

// ❌ Arbitrary wait/sleep
await page.waitForTimeout(5000)  // What are we waiting for?

// ❌ setTimeout in test
setTimeout(() => {
  expect(result).toBe('complete')
}, 3000)

// ❌ Promise delay
await new Promise(resolve => setTimeout(resolve, 2000))
```

**Good Example:**

```typescript
// ✅ Speed profile controls timeout (no explicit timeout)
await expect(page.locator('.result')).toBeVisible()

// ✅ Wait for specific condition
await expect(page.locator('.status')).toHaveText('Complete')

// ✅ Wait for element to appear
const button = page.locator('button[data-action="submit"]')
await expect(button).toBeEnabled()

// ✅ Wait for count
await expect(page.locator('.item')).toHaveCount(5)

// ✅ Wait for state change
await page.waitForFunction(() => {
  return window.appState?.loaded === true
})
```

**Why Timeouts Are Anti-Patterns:**

1. **Arbitrary** - No connection to actual system state
2. **Flaky** - Sometimes too short, sometimes wastefully long
3. **Slow** - Always waits full duration even if condition met early
4. **Unclear** - Doesn't document what we're waiting for
5. **Brittle** - Breaks when system timing changes

**Good Pattern - Wait for Conditions:**

```typescript
// Helper for custom conditions
async function waitForCondition(
  condition: () => boolean | Promise<boolean>,
  errorMessage: string
): Promise<void> {
  await page.waitForFunction(condition, { timeout: undefined })  // Speed profile controls
}

// Usage
slow('processes data', async ({ page }: { page: Page }): Promise<void> => {
  await page.goto('/processor')
  await page.locator('#data').fill('test data')
  await page.locator('button[data-action="process"]').click()
  
  // Wait for actual result, not arbitrary time
  const result = page.locator('.processing-result')
  await expect(result).toBeVisible()
  await expect(result).toContainText(/processed/i)
})
```

**Why**: Waiting for conditions is deterministic, fast, and documents intent.

---

### [TEST-FE][!WAIT-FOR-ELEMENTS]

**Rule**: Wait for specific elements, not network idle.

**Bad Example:**

```typescript
// ❌ Network idle wastes time
await page.waitForLoadState('networkidle')

// ❌ Arbitrary delay
await page.waitForTimeout(3000)
```

**Good Example:**

```typescript
// ✅ Wait for specific element
const result = page.locator('.data-loaded')
await expect(result).toBeVisible()

// ✅ Wait for text content
const status = page.locator('.status')
await expect(status).toHaveText('Ready')

// ✅ Wait for count
const items = page.locator('.list-item')
await expect(items).toHaveCount(5)
```

**Why**: Waiting for specific elements is faster and more reliable.

---

### [TEST-FE][!TYPED-PAGE-OBJECTS]

**Rule**: Use typed page object models for complex pages.

**Good Example:**

```typescript
class AgentPage {
  constructor(private readonly page: Page) {}
  
  async goto(): Promise<void> {
    await this.page.goto('/agent')
  }
  
  async fillGoal(goal: string): Promise<void> {
    await this.page.locator('#goal').fill(goal)
  }
  
  async clickGenerate(): Promise<void> {
    await this.page.locator('button[data-action="generate"]').click()
  }
  
  async waitForPlan(): Promise<void> {
    await expect(this.page.locator('.plan-result')).toBeVisible()
  }
  
  async getMilestoneCount(): Promise<number> {
    return await this.page.locator('.milestone').count()
  }
}

// Usage
slow('generates plan', async ({ page }: { page: Page }): Promise<void> => {
  const agentPage = new AgentPage(page)
  
  await agentPage.goto()
  await agentPage.fillGoal('Add health check')
  await agentPage.clickGenerate()
  await agentPage.waitForPlan()
  
  const count: number = await agentPage.getMilestoneCount()
  expect(count).toBeGreaterThan(0)
})
```

**Why**: Page objects provide type-safe, reusable page interactions.

---

## Speed Profiles

- **Fast** (<5s): UI only, no network calls
- **Medium** (<15s): API calls, no LLM
- **Slow** (<30s): Real LLM integration, SSE streams

---

## Commands

### [TEST-FE][!USE-STANDARDIZED-SCRIPTS]

**Rule**: Always use standardized scripts from `bin/` directory. Never run test commands directly via npm.

**Why**: Scripts provide consistent environment setup, server lifecycle management, cleanup, and error handling across frontend and backend.

**Good Example:**

```bash
# E2E tests (with backend server)
bin/e2e

# E2E with speed filter
bin/e2e fast
bin/e2e medium
bin/e2e slow

# Specific E2E test file
bin/e2e tests/execution-flow.test.ts

# Frontend unit tests
bin/test-fe

# Unit tests with coverage
bin/test-fe --coverage
```

**Bad Example:**

```bash
# DON'T: Direct npm commands bypass script safeguards
npm run test:e2e
npx playwright test
npm test
```

**Why**: The standardized scripts (following patterns in `script_design.md`) handle:
- Backend server startup for E2E tests
- Frontend dev server if needed
- Port cleanup before starting
- Speed profile filtering
- Colored output
- Server shutdown on Ctrl+C
- Exit code handling

**See**: `docs/how_to/back_end/script_design.md` for script patterns

---

## Summary

**Key Principles:**

1. **Standardized scripts** - Always use `bin/e2e`, `bin/test-fe`, never direct commands
2. **TypeScript strict** - Full type safety
3. **Typed factories** - Type-safe test data
4. **beforeEach()** - Reusable setup
5. **Isolated contexts** - Nested describe blocks
6. **Input/Output** - Test public interface only
7. **Speed profiles** - fast/medium/slow functions
8. **Wait for conditions** - Never use explicit timeouts
9. **Wait for elements** - Explicit element expectations

**Benefits:**

- Type-safe tests
- Clear test organization
- Fast execution
- Reliable E2E tests
- No flakiness

**Script Integration:**

Every test run should go through standardized scripts that provide:
- Backend server startup/shutdown for E2E tests
- Consistent environment setup
- Port cleanup before starting
- Speed profile filtering
- Colored output
- Cleanup on exit/interrupt
- Error handling

See `script_design.md` for full script patterns.
