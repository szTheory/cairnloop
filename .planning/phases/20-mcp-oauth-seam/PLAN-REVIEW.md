## ISSUES FOUND

**Phase:** 20-mcp-oauth-seam
**Plans checked:** 1
**Issues:** 2 blocker(s), 1 warning(s), 0 info

### Blockers (must fix)

**1. [scope_sanity] Plan 01 has 5 tasks - exceeds context budget**
- Plan: 01
- Fix: Split into 2 plans: e.g., Plan 01 (Migration, Schema, Context) and Plan 02 (Plugs and Router Integration).

**2. [nyquist_compliance] VALIDATION.md not found for phase 20.**
- Plan: null
- Fix: Re-run `/gsd-plan-phase 20 --research` to regenerate the missing VALIDATION.md file.

### Warnings (should fix)

**1. [pattern_compliance] Tasks do not reference their respective analogs from PATTERNS.md in the action sections.**
- Plan: 01
- Fix: Add explicit references and excerpts to the analogs (e.g., `lib/cairnloop/governance/tool_proposal.ex` for Token Schema, `lib/cairnloop/governance.ex` for Context) in the task `<action>` blocks. Also ensure Shared Patterns (like "Plug Construction") are referenced.

### Structured Issues

```yaml
issues:
  - plan: "01"
    dimension: "scope_sanity"
    severity: "blocker"
    description: "Plan 01 has 5 tasks, which exceeds the context budget threshold of 4 max (2-3 recommended). This increases the risk of quality degradation during execution."
    fix_hint: "Split the plan into two plans: e.g. 20-01 (DB, Schema, and Context API) and 20-02 (AuthPlug, WellKnownPlug, and Router)."
    metrics:
      tasks: 5
      files: 9
  - plan: null
    dimension: "nyquist_compliance"
    severity: "blocker"
    description: "VALIDATION.md not found for phase 20."
    fix_hint: "Re-run `/gsd-plan-phase 20 --research` to regenerate."
  - plan: "01"
    dimension: "pattern_compliance"
    severity: "warning"
    description: "Tasks create files listed in PATTERNS.md but do not explicitly reference the analog files or Shared Patterns in their action sections."
    fix_hint: "Update tasks 1-4 to mention their PATTERNS.md analogs and excerpts (e.g., reference `lib/cairnloop/governance.ex` in the Context task)."
```

### Recommendation

2 blocker(s) require revision. Returning to planner with feedback.
