# Phase 12: In-Thread Quick Fix & Ops Closure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `12-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-22
**Phase:** 12-in-thread-quick-fix-ops-closure
**Areas discussed:** launch point and handoff, evidence packaging, fail-closed fallback, ops closure and visibility

---

## Launch point and handoff

| Option | Description | Selected |
|--------|-------------|----------|
| Evidence-rail CTA -> create/reuse suggestion + review task -> deep-link into shared review lane | Launch from the existing conversation evidence rail, create or reuse durable maintenance artifacts, and land in the shared review inbox detail. | ✓ |
| Evidence-rail CTA -> intermediate authoring/manual step first -> optional review task later | Open a manual authoring path before any review-task artifact exists. | |
| Composer/header/tool-style action -> deep-link into review lane | Surface the action as a faster thread action outside the evidence rail. | |

**User's choice:** Agent-selected recommendation per user preference to shift low-impact decisions left.
**Notes:** Locked to the evidence-rail launch because it best matches the existing `ConversationLive` posture, preserves one maintenance lane, and avoids overloading the generic tool registry or composer semantics.

---

## Evidence packaging

| Option | Description | Selected |
|--------|-------------|----------|
| Current thread only | Use only the live thread to seed the quick fix. | |
| Canonical-only subset | Use only citation-eligible canonical KB retrieval results. | |
| Layered bundle: current thread + canonical retrieval + bounded resolved-case evidence | Keep live thread signal, canonical citation anchors, and a small assistive case layer with explicit trust separation. | ✓ |
| Full omnibus bundle | Mix thread context with broad retrieved and external evidence. | |

**User's choice:** Agent-selected recommendation per user preference to shift low-impact decisions left.
**Notes:** Locked to a typed layered bundle. Canonical retrieval remains the only citation-eligible layer; thread and resolved-case layers remain assistive/contextual only.

---

## Fail-closed fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Reviewable draft shell | Create a shell artifact when grounding is weak but the maintenance need is still real. | |
| Direct manual authoring handoff | Send operators directly into manual editing when AI cannot safely prepare work. | |
| Blocked action with operator-visible reason | Stop the workflow and explain why quick fix could not proceed safely. | |
| Hybrid by failure class | Choose shell vs blocked/manual-required based on the actual failure mode. | ✓ |

**User's choice:** Agent-selected recommendation per user preference to shift low-impact decisions left.
**Notes:** Locked to a bounded failure-class model: shell for partial-but-actionable evidence, blocked/manual-required for missing or invalid canonical grounding, and manual authoring as an explicit operator choice rather than the default path.

---

## Ops closure and visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry only | Emit bounded maintenance telemetry and rely on external observability tools for visibility. | |
| Telemetry + small embedded status surfaces | Add bounded telemetry plus lightweight in-thread/review-lane status visibility where operators already work. | ✓ |
| Broader ops dashboard | Add a new operational dashboard with trend and queue-health views. | |

**User's choice:** Agent-selected recommendation per user preference to shift low-impact decisions left.
**Notes:** Locked to telemetry plus embedded status surfaces. Workflow truth remains in durable `Ecto` state; telemetry is for observability, not audit truth.

---

## the agent's Discretion

- Exact naming for typed evidence package modules and fallback enums.
- Exact card copy, status badges, and route params.
- Exact telemetry event names and metadata field naming within the bounded taxonomy.
- Exact `Oban` uniqueness keys and presenter extraction details, so long as they preserve idempotency and low-cardinality observability.

## Deferred Ideas

- Standalone ops or analytics dashboard for KB maintenance trends.
- Broader support action bars or command-palette style thread workflows.
- Approval-publish convenience shortcuts.
- Multi-reviewer or governed-tool expansion beyond the current shared review lane.
