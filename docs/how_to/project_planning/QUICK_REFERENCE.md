---
description: Quick reference card for project planning patterns
globs: ""
alwaysApply: false
---

# Project Planning Quick Reference

**Purpose**: Fast rule scanning for project planning

---

## Planning Process

`[PLAN][!RESEARCH-FIRST]` - Research docs/references before planning; source code only when docs insufficient  
`[PLAN][!PROJECT-DIRECTORY-NAMING]` - Create directory: `docs/projects/{YYYY-MM-DD}_{project_name}/`  
`[PLAN][!FILE-REFERENCES-COMPLETE]` - List ALL existing and planned files with Before/Added tree sections

---

## Structure

`[PLAN][!MILESTONES-LOGICAL-GROUPS]` - Milestones are logical groupings (3-7 steps) with demonstrable outcomes  
`[PLAN][!STEPS-SMALL-AND-FOCUSED]` - Each step: small (one session), has Intent/Details/Tests, builds incrementally  
`[PLAN][!EVERY-STEP-HAS-TESTS]` - Every step has Tests section: unit + integration + edge cases  
`[PLAN][!NO-IMPLEMENTATION-CODE]` - Plans describe what and why, never how; no code in Details section

---

## Execution

`[PLAN][!EXECUTION-ONE-STEP-AT-A-TIME]` - Execute sequentially: tests first, run before next step, commit after milestones

---

## Quick Flow

```
1. Research (docs/references) → 
2. Create project directory (dated) → 
3. Write file_references.md (all files + trees) → 
4. Write project_plan.md (milestones + steps) → 
5. Execute: Step → Tests → Implement → Verify → Next Step → Commit after Milestone
```

---

## Step Template

```markdown
### {M}.{S} - {Step Title}

**Intent**: What + why + how it fits

**Details**:
- Requirements (no code)
- Attributes/parameters
- Validation rules
- Integration points

**Tests**:
- Unit: [test cases]
- Integration: [test cases]
- Edge Cases: [test cases]
```

---

## Cross-Reference

- **Full Planning Guide**: `project_planning/project_plan_structure.md`


