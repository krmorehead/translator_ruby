# Setup Guide - translator_ruby

## Required Environment Variables

### AGENT_DATA_PATH (REQUIRED)

**Must be set in all environment files**:

```bash
# .env.development
AGENT_DATA_PATH=.agents

# .env.test
AGENT_DATA_PATH=.agents-test

# .env.production
AGENT_DATA_PATH=/var/app/agents
```

**What it does**:
- Defines where agent session data is stored (memories, workflows, outputs)
- **Separate from working directory** (where agents investigate/modify code)
- Follows strict OOP principles: **NO fallbacks, FAILS LOUDLY if not set**

**Why it's required**:
- Prevents pollution of project root with UUID directories
- Clear separation of concerns: storage vs working directory
- Explicit configuration over implicit defaults

**If not set**:
```
KeyError: key not found: "AGENT_DATA_PATH"
```

This is **intentional** - better to fail than silently use wrong directory.

## Setup Steps

1. **Copy environment templates**:
   ```bash
   cp .env.example .env.development
   cp .env.example .env.test
   ```

2. **Set AGENT_DATA_PATH** in each file:
   ```bash
   # .env.development
   AGENT_DATA_PATH=.agents
   
   # .env.test
   AGENT_DATA_PATH=.agents-test
   ```

3. **Run tests**:
   ```bash
   bundle exec rails test
   ```

4. **Start server**:
   ```bash
   rails server -p 4000
   ```

## Directory Structure

After setup:
```
translator_ruby/
├── .agents/          # Development agent data
│   └── {session-id}/
│       ├── memory.json
│       └── workflows/
├── .agents-test/     # Test agent data (isolated)
│   └── {session-id}/
│       ├── memory.json
│       └── workflows/
├── app/
├── config/
└── test/
```

## OOP Principles Enforced

1. **NO fallbacks** - Uses `ENV.fetch("AGENT_DATA_PATH")`
2. **NO conditionals** - Single responsibility
3. **Fails loudly** - Clear errors if misconfigured
4. **Separation of concerns**:
   - Storage: `AgentConfig.data_path`
   - Working: `params[:project_path]`

See `docs/references/oop-patterns.md` for full principles.

