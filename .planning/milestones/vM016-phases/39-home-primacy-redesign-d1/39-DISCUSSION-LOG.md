# Phase 39: Home Primacy Redesign (D1) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 39-home-primacy-redesign-d1
**Areas discussed:** Resolved filter, Fail-closed counts, Zero state, Health in band

---

## Resolved filter (HOME-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Query-param + clear | `/inbox?status=resolved` + `handle_params/3`; quiet "Showing resolved · Show all" affordance; no new route, no tab UI | ✓ |
| Full filter UI | Standing status filter/tab bar (All/Open/Resolved/…) | |
| Discuss it | Walk the trade-offs before locking | ✓ (requested deep research) |

**User's choice:** "discuss the pros/cons/tradeoffs… i don't want to half-ass this work
toward the ideal… research using subagents… idiomatic for elixir/plug/ecto/phoenix…
lessons learned from other libs/apps in same space… footguns… great DX/UX… consider
prompts/ research… one-shot a perfect coherent set of recommendations so i don't have to
think… idk which direction i want to do it right tho."
**Notes:** Ran two parallel research agents (architecture/idiomatic-Phoenix +
product-IA/competitive-UX). Both **converged independently on the query-param +
`handle_params/3`** approach, backed by an additive `Chat.list_conversations/1` scoped
Ecto query + `count_conversations/1` (which also satisfies HOME-05's scoped counts), with
a quiet `cl_chip` applied-filter line + `cl_empty` filtered-empty state. Rejected:
`live_action` route (bloats host-owned routing), assign-only tabs (not URL-addressable),
streams refactor (churns sealed paths). Locked per the owner's explicit "one-shot it"
delegation; flagged for cheap veto. Also surfaced a pre-existing duplicate-`href` bug on
the Home "Recover resolved" `cl_stat`. See CONTEXT.md D-01…D-05, D-10.

---

## Fail-closed counts

| Option | Description | Selected |
|--------|-------------|----------|
| Distinct unavailable line | Fail-closed 0 for the number, but a quiet neutral "Count unavailable" sub-line so error ≠ calm-zero | ✓ |
| Conflate error with calm-zero | Accept fail-closed 0 == calm success state (simplest, but dishonest on a Repo hiccup) | |
| Discuss it | | |

**User's choice:** Distinct unavailable line (recommended).
**Notes:** `cl_hero`/`cl_stat` are numeric-only post-P37, so the old `"—"` string no
longer type-checks. Keep honest/reason-forward copy. CONTEXT.md D-06.

---

## Zero state (HOME-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Hero swaps, band persists | Hero becomes a calm `cl_empty` success block; secondary band stays visible below | ✓ |
| Whole-page celebration | Entire Home collapses to one success state, hiding the band | |
| Discuss it | | |

**User's choice:** Hero swaps, band persists (recommended).
**Notes:** No confetti. Band keeps Tend/Audit/Health reachable at zero. CONTEXT.md D-07.

---

## Health in band (HOME-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Same tile, chip in count slot | Health uses the same secondary-tile shape but renders a `cl_chip` (Healthy/Degraded) where the number would go — uniform 3-up grid | ✓ |
| Distinct health cell | Visually distinct treatment so it reads as a status check, not a count | |
| Discuss it | | |

**User's choice:** Same tile, chip in count slot (recommended).
**Notes:** Never a numeric slot; state by icon + text, never color alone. CONTEXT.md D-08.

---

## Claude's Discretion

- Scoped counts + throttle (HOME-05): scoped `count_conversations/1` sharing
  `scope_status/2` with the list query; throttle PubSub recount via `Process.send_after`
  + pending flag (interval ~500ms–1s, exact value planner discretion). CONTEXT.md D-09.
- Exact `cl_empty` icons, microcopy wording, and the single small `.cl-applied-filter`
  layout class.

## Deferred Ideas

- Standing inbox filter chrome (tab bar / segmented control / dropdown / saved-views;
  per-status counts) → future inbox-filtering phase.
- Phoenix streams refactor of the inbox list → additive later only if list grows unbounded.
- "Next in queue" threading and Audit-row → subject linking → later IA-threading phases.
