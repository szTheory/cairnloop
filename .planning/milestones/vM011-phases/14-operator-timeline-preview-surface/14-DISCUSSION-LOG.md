# Phase 14: Operator Timeline & Preview Surface - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-24
**Phase:** 14-operator-timeline-preview-surface
**Areas discussed:** Placement & affordances, State labels & copy, Preview fidelity & trust, Evidence link meaning

---

## How this discussion ran

The user selected all four gray areas, then directed: *"for each of these… research using
subagents — pros/cons/tradeoffs, what is idiomatic for Elixir/Phoenix/Ecto/Oban and this
ecosystem, lessons from comparable successful libs/apps (other languages OK), footguns, great
DX/UX… one-shot a perfect coherent set of recommendations so I don't have to think… shift this
preference left within GSD… except for VERY impactful ones that I might actually care about."*

Accordingly, the menu questions were **not** answered by selection. One deep-research subagent was
dispatched per area; their findings were reconciled into one coherent decision set in CONTEXT.md
(D-01..D-27). Only the single trust-sensitive call (D-15) is flagged back for ratification.

This matches the standing preference recorded in memory (`decision-research-shift-left`).

---

## Placement & affordances

| Option | Description | Selected |
|--------|-------------|----------|
| Rail timeline section | Dedicated "Governed actions" list in the right evidence rail, consistent with quick_fix_card/draft_audit_card | ✓ (D-01) |
| Inline in message thread | Interleave proposal cards chronologically in the message-timeline | |
| Both: rail + inline marker | Full card in rail + lightweight inline marker | |
| Reframe "Execute"→"Propose", keep launcher + timeline | Rename button; launcher stays in Actions; add read-only timeline | ✓ (D-04) |
| Fold launcher into the timeline | Single unified surface | |
| Timeline-only, drop launchers | Show only existing proposals | |

**User's choice:** Delegated to research. **Decided:** rail section + plain-assign rendering (no
streams) + function component + reframe Execute→Propose + read-only card with a Phase-15 footer
slot. Plus the cross-cutting data linkage: Phase-14-owned nullable `conversation_id` migration +
narrow `list_proposals_for_conversation/1` read helper (D-01..D-09).
**Notes:** Research converged on keeping customer dialogue (center) separate from operator evidence
(rail); streams rejected for a bounded per-conversation list; `conversation_id` excluded from the
idempotency key.

---

## State labels & copy

| Option | Description | Selected |
|--------|-------------|----------|
| Operator vocabulary | Calm labels + grouping for proposed/needs_input/scope_invalid/policy_denied | ✓ (D-10..D-14) |

**User's choice:** Delegated to research. **Decided:** four stable groups (Awaiting / Blocked /
Active / Done, last two reserved for Phase 15/16); labels "Proposed" / "Needs input" / "Not
available here" / "Blocked by policy"; the `:proposed`+`:requires_approval` case labeled honestly
("Proposed" + future-tense gate sub-line, never "Pending approval" yet); status/risk/approval kept
as separate axes; `inspect(reason)` replaced with `reason_label/1`.
**Notes:** Key lesson — bare "Pending" is a documented ambiguity footgun; never name an action
(Approve) that doesn't exist yet (Stripe/GitHub precedent); never collapse distinct states.

---

## Preview fidelity & trust

| Option | Description | Selected |
|--------|-------------|----------|
| A — Live re-derivation | Rebuild struct from snapshot + call current preview/1; title from live Spec | |
| B — Snapshot at propose | Reopen Phase 13 propose/3 + migration to persist rendered preview + title | (deferred to P15/16) |
| C — Hybrid | Trust fields strictly from snapshot; prose live best-effort, labelled "current", behind fallback | ✓ (D-15) |

**User's choice:** Delegated to research; **flagged for ratification** as the one trust call.
**Decided:** Hybrid (C) for Phase 14 (inert proposals), with an additive promotion to snapshotting
the consequence/title in Phase 15/16 (D-16). Structured-summary fallback is the *common* path
(no tool implements `preview/1` yet) and is built entirely from the snapshot (D-17). Rehydration
footguns enumerated (JSONB atom→string keys is the central trap) (D-19).
**Notes:** Tied to P13 D-14/D-24 (never re-read live config for trust fields). Drift on inert prose
is benign; it becomes a real trust hole the moment a human approves/executes — hence the promotion.

---

## Evidence link meaning

| Option | Description | Selected |
|--------|-------------|----------|
| Provenance model | Audit-event trail + inline humanized snapshots + policy "why this gate" sentence + source conversation; never raw JSON / never telemetry | ✓ (D-20..D-24) |

**User's choice:** Delegated to research. **Decided:** "evidence" = provenance (NOT retrieval
grounding — don't fabricate sources). Card surfaces: consequence+risk+approval headline (inline),
input snapshot rows (inline humanized), action-event trail via `list_events/1` (inline compact +
expander), scope snapshot (missing scopes prominent on block), policy snapshot as one calm
sentence, source conversation (co-located), trace metadata (de-emphasized). `input_rows/1` is the
PII masking choke point; `history_line/1` gets a forward-compat catch-all.
**Notes:** Reuse `humanize_context_label`/`context_field`; telemetry is never a UI source (P13 D-29);
OBS-02 attribution and the Scoria lane stay deferred.

---

## Claude's Discretion

Exact module/function/CSS names, label/copy wording (within brand voice), card markup, expander
mechanism, ordering tie-breaks, empty-state copy, and Phase-15 footer-slot placement — all
planner/executor discretion as long as the locked shapes/trust boundaries hold (CONTEXT D-27 + the
Claude's Discretion section).

## Deferred Ideas

FLOW-03 reject/defer (P15); approval state machine + Oban resume + "Pending approval" action (P15);
snapshotting rendered consequence/title (P15/16, additive); execution + results rendering (P16);
`LiveView.stream/3` for the timeline (re-evaluate P16); OBS-02 attribution (P16/17); Scoria /
read-only MCP seam (P17); standalone cross-conversation audit-log page (out of scope).
</content>
