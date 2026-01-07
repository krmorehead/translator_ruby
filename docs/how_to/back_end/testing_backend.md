---
description: RSpec testing patterns with FactoryBot and speed profiles
globs: spec/**/*_spec.rb
alwaysApply: false
---

# Backend Testing Patterns

**Tags**: [testing, back_end]  
**Applies To**: RSpec + FactoryBot (Ruby/Rails)  
**Date**: 2026-01-06

## Overview

RSpec testing with FactoryBot, strong Sorbet typing, speed profiles, let() for reusable variables, and input/output focused testing. No mocks, no timeouts, real instances only.

## Test Organization Tree

```
RSpec Test Suite (typed: strict)
│
├── Speed Profiles (enforced SLAs)
│   ├── Fast (<10s): Pure logic, validations, no I/O
│   ├── Medium (<60s): File I/O, database, API (no LLM)
│   └── Slow (<120s): LLM integration, complex workflows
│
├── FactoryBot Factories (Typed)
│   ├── spec/factories/executions.rb
│   │   factory :execution do
│   │     id { UUID.generate }
│   │     status { :pending }
│   │     trait :running
│   │     trait :complete
│   │   end
│   │
│   └── spec/factories/contexts.rb
│       factory :sisyphus_context do
│         trait :with_entries
│       end
│
└── Test Pattern: Input → Output
    ├── Arrange: let(:input) { build(:execution) }
    ├── Act: result = service.process(input: input)
    └── Assert: expect(result).to be_a(ExpectedType)
        ❌ Don't test @internal_state
        ✅ Only test public outputs
```

---

## Rules

### [TEST][!RSPEC-FACTORYBOT-LET]

**Rule**: Use RSpec structure (describe/context/it), FactoryBot for domain objects, and let() for reusable variables.

**Good Example:**

```ruby
# typed: strict
# spec/models/execution_spec.rb

require 'rails_helper'

RSpec.describe Execution, type: :model do
  speed_profile :fast
  
  # Lazy evaluation with let()
  let(:execution) { build(:execution, status: :pending) }
  let(:service) { described_class.new }
  
  describe '#start' do
    it 'transitions to running status' do
      result = execution.start
      
      expect(result.status).to eq(:running)
      expect(result).to be_a(Execution)
    end
    
    context 'when already running' do
      let(:execution) { build(:execution, :running) }
      
      it 'raises error' do
        expect { execution.start }.to raise_error(InvalidStateError)
      end
    end
  end
  
  describe '#validate_status' do
    it 'accepts valid status input' do
      expect { build(:execution, status: :pending) }.not_to raise_error
    end
    
    it 'rejects invalid status input' do
      expect { build(:execution, status: :invalid) }.to raise_error(ArgumentError)
    end
  end
end
```

**FactoryBot Pattern:**

```ruby
# typed: strict
# spec/factories/executions.rb

FactoryBot.define do
  factory :execution do
    id { UUID.generate }
    status { :pending }
    metadata { {} }
    
    trait :running do
      status { :running }
      started_at { Time.now.utc }
    end
    
    trait :complete do
      status { :complete }
      completed_at { Time.now.utc }
    end
  end
end

# Usage
let(:pending_execution) { build(:execution) }
let(:running_execution) { build(:execution, :running) }
let(:custom_execution) { build(:execution, metadata: { priority: 'high' }) }
```

**Why**: RSpec provides clear structure. FactoryBot ensures consistent test data. let() provides lazy evaluation for better performance.

---

### [TEST][!INPUT-OUTPUT-NO-MOCKS]

**Rule**: Test inputs and outputs only. Use real instances from FactoryBot, not mocks. Never test internal state or private methods.

**Bad Example:**

```ruby
# ❌ Testing internals + mocks
it 'sets internal flag' do
  service.process(input: 'test')
  expect(service.instance_variable_get(:@internal_flag)).to be true  # ❌
end

it 'uses mocked dependency' do
  mock_store = double('StateStore')  # ❌ Mock
  allow(mock_store).to receive(:save)
  service = Service.new(store: mock_store)
end
```

**Good Example:**

```ruby
# typed: strict

# ✅ Test public interface only with real instances
RSpec.describe DataProcessor do
  speed_profile :fast
  
  let(:processor) { described_class.new }
  let(:real_store) { build(:state_store) }  # ✅ Real instance
  
  describe '#process' do
    it 'transforms input to expected output' do
      input = 'test data'
      
      result = processor.process(input: input)
      
      # ✅ Test output only
      expect(result).to eq('PROCESSED: test data')
      expect(result).to be_a(String)
    end
    
    it 'raises error for invalid input' do
      expect {
        processor.process(input: nil)
      }.to raise_error(ArgumentError, /input cannot be nil/)
    end
  end
end

# ✅ Real filesystem, no mocks
RSpec.describe ToolExecutionService do
  speed_profile :medium
  
  let(:temp_dir) { Dir.mktmpdir }
  let(:test_file) { File.join(temp_dir, 'test.txt') }
  
  before { File.write(test_file, 'test content') }
  after { FileUtils.rm_rf(temp_dir) }
  
  it 'lists directory contents' do
    result = service.execute_file_tree(path: temp_dir, max_depth: 1)
    
    expect(result[:success]).to be true
    expect(result[:files]).to include('test.txt')
  end
end
```

**Why**: Testing inputs/outputs ensures contracts without coupling to implementation. Real instances test actual integration without mock drift.

---

### [TEST][!WAIT-FOR-CONDITIONS]

**Rule**: Never use explicit timeouts or sleeps. Wait for actual conditions, not arbitrary time periods.

**Bad Example:**

```ruby
# ❌ Arbitrary timeout/sleep
it 'waits for process' do
  service.start_async_process
  sleep(5)  # ❌ Arbitrary wait
  expect(service.status).to eq(:complete)
end

# ❌ Explicit timeout
Timeout.timeout(10) do  # ❌
  service.execute
end
```

**Good Example:**

```ruby
# ✅ Wait for actual condition
it 'waits for process to complete' do
  service.start_async_process
  
  wait_for { service.status == :complete }
  
  expect(service.status).to eq(:complete)
end

# ✅ Use speed profile for test timeout
RSpec.describe LongRunningService do
  speed_profile :slow  # ✅ Entire spec gets appropriate timeout
  
  it 'completes processing' do
    result = service.execute  # No explicit timeout
    expect(result).to be_complete
  end
end

# Helper
module WaitHelper
  def wait_for(max_wait: 10, &block)
    start_time = Time.now
    loop do
      return if block.call
      raise "Condition not met" if Time.now - start_time > max_wait
      sleep 0.1
    end
  end
end
```

**Why**: Timeouts are arbitrary and cause flaky tests. Wait for actual conditions instead.

---

### [TEST][!REAL-LLM-SLOW-PROFILE]

**Rule**: LLM tests call real APIs with speed_profile :slow. Never mock LLM responses. Assert output structure and types.

**Good Example:**

```ruby
# typed: strict

RSpec.describe Planning::PlanGenerationPrompt do
  speed_profile :slow  # ✅ Real LLM takes time
  
  let(:goal) { 'Add health check endpoint' }
  let(:prompt) { described_class.new(goal: goal, path: '/codebase') }
  
  describe '#execute' do
    it 'generates plan with real LLM' do
      result = prompt.execute
      
      # ✅ Assert type first, then structure, then values
      expect(result[:plan]).to be_present
      expect(result[:plan][:milestones]).to be_an(Array)
      expect(result[:plan][:milestones].length).to be > 0
      expect(result[:usage][:total_tokens]).to be > 0
      
      first_milestone = result[:plan][:milestones].first
      expect(first_milestone[:description]).to be_present
    end
    
    context 'with invalid input' do
      let(:goal) { '' }
      
      it 'raises validation error' do
        expect { prompt.execute }.to raise_error(ArgumentError)
      end
    end
  end
end
```

**Why**: Real LLM integration tests ensure actual API contracts are met. Consistent expectations (type → structure → value) make tests predictable.

---

### [TEST][!USE-STANDARDIZED-SCRIPTS]

**Rule**: Always use standardized scripts from `bin/` directory. Never run test commands directly.

**Good Example:**

```bash
# ✅ Use scripts
bin/test
bin/test fast
bin/test medium
bin/test slow
bin/test spec/models/execution_spec.rb
```

**Bad Example:**

```bash
# ❌ Direct commands bypass safeguards
bundle exec rspec
SPEED_PROFILE=fast bundle exec rspec
```

**Why**: Scripts handle environment setup, server lifecycle, port cleanup, speed profile filtering, and cleanup on interrupt.

**See**: `script_design.md` for script patterns

---

## Speed Profiles

```ruby
RSpec.describe MyClass do
  speed_profile :fast  # <10s: Pure logic, validations
  
  context 'with LLM', speed_profile: :slow do  # <120s: LLM integration
    # Override for specific context
  end
end
```

- **Fast** (<10s): Pure logic, validations, no I/O
- **Medium** (<60s): File I/O, database, API calls (no LLM)
- **Slow** (<120s): LLM integration, complex workflows

---

## Summary

**Key Principles:**

1. **Standardized scripts** - Always use `bin/test`
2. **RSpec + FactoryBot** - describe/context/it + factories with traits
3. **let()** - Lazy evaluation for reusable variables
4. **Input/Output only** - Test public interface, not internals
5. **Real instances** - No mocks, use FactoryBot
6. **No timeouts** - Wait for conditions, not time
7. **Real LLM** - No mocking, speed_profile :slow
8. **Consistent expectations** - Type → structure → value
9. **Speed profiles** - Fast/medium/slow organization
10. **Sorbet strict** - Full type safety

**Benefits:**

- Clear, readable tests with RSpec structure
- Fast performance with lazy let()
- Consistent test data with FactoryBot
- Real integration testing without mocks
- No flaky tests (no timeouts)
- Type-safe with Sorbet

