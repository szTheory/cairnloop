# Thread: vM012 Pre-Planning Assessment

**Created:** 2026-05-25
**Status:** Active — feeds into `/gsd:new-milestone` for vM012
**Context:** Adopter-first assessment run before kicking off vM012. Three parallel Explore agents read all planning docs, ~98 source modules, MILESTONES.md, SECURITY.md, and prompts/ research.

---

## Assessment Summary

**Done %:** 82–87% — Strong, meaningful wedges remain.

**What caps the ceiling:** No runnable example app and the package is unpublished (Mix.exs `0.1.0`; hex.pm returns 404). These are adopter-facing gaps, not architecture gaps — everything else is well-built.

**Rubric breakdown:**
- Core JTBD (deflect/draft/escalate/knowledge-loop): 90%+
- Breadth vs. category expectations: 80%
- Docs/onboarding/examples: **65%** ← main gap
- Operator/admin/diagnostic posture: 88%
- Proof/CI posture: 85%

---

## Priority Stack for vM012

| Phase | Wedge | Why It's First |
|-------|-------|---------------|
| 18 | Release gate + v0.1.0 hex.pm publish | Hard June 2 CI deadline; package 404 blocks all adoption |
| 19 | Example Phoenix app | Highest adopter leverage; multiplies value of all existing work; no new architecture |
| 20 | MCP-02: Remote OAuth + tool projection | Natural next expansion per vM011 decisions; reuses `Governance.propose/3` |
| 21 | MCP-03 / ACT-02: `tools/call` pipeline + second tool type | Proves `tools/call` and tool generalization beyond InternalNote |
| 22 (opt) | SECURITY.md debt: T-10-09..T-10-13 | 5 open KB surface threats from vM010; close before KB surfaces expand |

---

## Key Risks

1. **Node.js CI deadline — June 2, 2026** (hard): GitHub forces Node.js 24 default. Must update `.github/workflows/ci.yml` before first Phase 18 execute. STATE.md Hygiene Gate item #2.
2. **Package unpublished**: `mix hex.publish` has never been run. `mix hex.publish --dry-run` should be the first release-gate verification step.
3. **SECURITY.md open threats (T-10-09..T-10-13)**: KB maintenance surfaces (editor handoff, authoring-target seam, stale gate inputs). Not blocking vM012 start, but should close before KB surfaces expand in later milestones.
4. **No example app**: Until one exists, every claim in the README is "trust me." An adopter can't evaluate the lib without running it.

---

## Diminishing Returns Boundary

**Keep pushing (vM012):**
- Release gate + hex.pm publish — unlocks adoption; hard deadline
- Example app — high multiplier; no new architecture
- MCP write — one meaningful feature wedge; contract is proven

**Defer to vM013 or later:**
- FLOW-04 multi-step runbooks — needs ACT-02 first; adds orchestration complexity
- Autonomous customer-visible replies — out of scope by governance philosophy
- Full MCP server (streaming, resources, prompts) — complexity before basic write proven

**Blunt verdict:** After vM012 (release + example + MCP write), step back. InternalNote is the only real tool. Adoption signals from real apps should drive ACT-02 and FLOW-04 priority — don't build them speculatively.

---

## Decisions Made in This Assessment

- Phase 18 is the gating phase — do NOT start feature phases before release gate closes
- Example Phoenix app targets `examples/` dir: `mix setup` → seed conversations → show draft/approval/KB publish
- MCP OAuth seam reuses `Governance.propose/3` entirely; zero core changes expected
- ACT-02 second tool type: low-blast-radius candidate (tag conversation, close ticket) — not financial/destructive first

---

## What Wasn't Changed (and Why)

- Out-of-scope list: unchanged — autonomous replies, raw tool output as truth, replacing Oban/Phoenix workflow truth all remain out of scope
- Key architectural decisions from vM011: all still valid (Ecto as workflow truth, snapshot at propose time, enum-only telemetry labels)
- FLOW-04 runbooks: remained deferred — needs ACT-02 solid first

---

## Next Step

Run `/gsd:new-milestone` with milestone name **"Public Release & MCP Write Surface"** starting at Phase 18.
