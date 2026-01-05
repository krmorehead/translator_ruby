# Agent Data Path Migration - Storage Cleanup

## 🎯 Problem Solved

**Issue**: Backend was polluting the project root with UUID-based session directories (56 directories!), mixing storage location with working directory.

**Root Cause**: `AGENT_DATA_PATH` environment variable was defaulting to `"."` (current directory), causing agent session data to be saved at the project root.

## ✅ Solution

### 1. Strict OOP Configuration Module

Created `AgentConfig` module with **NO fallbacks, NO conditionals**:

```ruby
# lib/agent_config.rb
module AgentConfig
  def self.data_path
    # FAILS LOUDLY if AGENT_DATA_PATH not defined
    ENV.fetch("AGENT_DATA_PATH")
  end
end
```

### 2. Separation of Concerns

**Storage Directory** (where agents save memories/workflows):
- Location: `AgentConfig.data_path` (from `AGENT_DATA_PATH` env var)
- Default: `.agents/` in Rails root
- **Never pollutes project root**
- **Independent of working directory**

**Working Directory** (where agents investigate/modify code):
- Location: Path passed from frontend (`project_path`, `path` params)
- Used by: File operations, Git operations, code analysis
- **Separate from storage**

### 3. Environment Variable Requirements

**MUST be defined in:**
- `.env.development` → `AGENT_DATA_PATH=.agents`
- `.env.test` → `AGENT_DATA_PATH=.agents-test`
- `.env.production` → `AGENT_DATA_PATH=/var/app/agents` (or similar)

**NO fallbacks** - application fails loudly if not configured.

### 4. All References Updated

Updated all code to use `AgentConfig.data_path` instead of `ENV.fetch("AGENT_DATA_PATH", ".")`:

**Models**:
- ✅ `app/models/memory_store.rb`
- ✅ `app/models/research_memory_store.rb`

**Workers**:
- ✅ `app/workers/base_worker.rb`
- ✅ `app/workers/daedalus_worker.rb`
- ✅ `app/workers/sisyphus_worker.rb`
- ✅ `app/workers/project_planner_worker.rb`
- ✅ `app/workers/actions/base_action.rb`

**Services**:
- ✅ `app/services/base_workflow.rb`
- ✅ `app/services/execution_output_service.rb`
- ✅ `app/services/project_plan_output_service.rb`

### 5. Cleanup

**Removed 56 polluted UUID directories** from project root:
```bash
rm -rf [0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*
rm -rf workflows
```

**Updated `.gitignore`**:
```
.agents/
.agents-test/
```

## 📊 Before vs After

### Before
```
translator_ruby/
├── 0896cb1f-4d0e-44bf-b425-1df6d9e8eff9/  ❌ Pollution!
│   └── workflows/
├── 6755b6c5-f958-4974-a6ff-882b65a77067/  ❌ Pollution!
│   └── workflows/
├── 6852c830-59bd-40cb-a12a-5bb7175885b8/  ❌ Pollution!
│   └── workflows/
├── ... (53 more UUID directories!) ❌
├── workflows/  ❌ Pollution!
├── app/
├── config/
└── lib/
```

### After
```
translator_ruby/
├── .agents/  ✅ Clean separation!
│   ├── {session-id-1}/
│   │   ├── memory.json
│   │   └── workflows/
│   ├── {session-id-2}/
│   │   ├── memory.json
│   │   └── workflows/
│   └── ...
├── app/
├── config/
└── lib/
```

## 🎯 Key Principles

### 1. No Fallbacks
```ruby
# ❌ BAD - Masks configuration issues
ENV.fetch("AGENT_DATA_PATH", ".")

# ✅ GOOD - Fails loudly if not configured
ENV.fetch("AGENT_DATA_PATH")
```

### 2. No Conditionals
```ruby
# ❌ BAD - Conditional logic
path = defined?(Rails) ? Rails.root.join(".agents").to_s : File.join(Dir.pwd, ".agents")

# ✅ GOOD - Single responsibility
ENV.fetch("AGENT_DATA_PATH")
```

### 3. Separation of Concerns
```ruby
# Storage path (memories, workflows)
AgentConfig.data_path  # → .agents/

# Working path (code to investigate/modify)
params[:project_path]  # → /path/to/user/project
```

## 🚀 Usage

### Development
```bash
# .env.development
AGENT_DATA_PATH=.agents
```

### Testing
```bash
# .env.test
AGENT_DATA_PATH=.agents-test
```

### Production
```bash
# .env.production
AGENT_DATA_PATH=/var/app/agents
```

## 📝 Migration Checklist

- ✅ Created `AgentConfig` module with strict validation
- ✅ Updated all 9 files to use `AgentConfig.data_path`
- ✅ Removed all fallback logic
- ✅ Cleaned up 56 polluted UUID directories
- ✅ Cleaned up `workflows/` directory
- ✅ Updated `.gitignore`
- ✅ Created `.agents/` directory
- ✅ Documented requirements

## ⚠️ Breaking Change

**Action Required**: Set `AGENT_DATA_PATH` in your `.env` files

If not set, application will fail with:
```
KeyError: key not found: "AGENT_DATA_PATH"
```

This is **intentional** - fail loudly instead of silently using wrong directory.

---

*Migration Completed: 2026-01-03*
*Files Updated: 9*
*Directories Cleaned: 57*
*Principle: NO FALLBACKS, NO CONDITIONALS, FAIL LOUDLY*

