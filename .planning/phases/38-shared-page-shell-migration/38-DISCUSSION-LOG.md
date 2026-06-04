# Phase 38: Shared Page-Shell Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 38-shared-page-shell-migration
**Areas discussed:** Deep-path breadcrumb behavior (SHELL-02). All other gray areas auto-decided
per shift-left + `minimal_decisive` tier (page-shell wrap pattern, width variant, slot mapping,
title copy, verification posture, conversation/Home/audit-link scope).

---

## Deep-path breadcrumb behavior (SHELL-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Origin-aware, editor only | When `return_to` present, prepend a back crumb to the origin conversation (≥2 crumbs + back link); fall back to static `Knowledge / Editing`. Only the editor changes. (Claude's recommendation — smallest honest change using existing verified data.) | |
| Origin-aware, editor + suggestion review | Same origin-aware trail, extended to `suggestion_review` on the from-conversation path. Broader consistency; pulls more surface in. | ✓ |

**User's choice:** Origin-aware, editor **and** suggestion_review.
**Notes:** Grounding correction recorded in CONTEXT.md D-01 — the editor receives a verified
conversation `return_to`; `suggestion_review` does not (it is a *producer* of editor handoffs and is
reached from the review lane via `task`/`queue` params, and has no breadcrumb today). Intent
(consistency across both KB detail screens) honored; suggestion_review's breadcrumb is origin-derived
from its review-lane context with the same prepend mechanism if a verified `return_to` is ever passed.
No conversation→suggestion_review handoff is invented (that would be P42 scope creep).

---

## Claude's Discretion

Auto-decided with recorded rationale (CONTEXT.md `<decisions>`); none bounced back to the owner:
- **D-02** — `cl_page` nests *inside* `cl_shell` (inner frame); per-screen `<h1>` → `title`.
- **D-03** — Width = `wide` for all migrated screens (`:reading` rail is P41).
- **D-04** — Slot mapping: `kb_nav` → `:subnav`; single primary action → `:actions`; large filter
  bars stay in body; breadcrumb → `:breadcrumb` slot.
- **D-05** — Title copy carried verbatim from current `<h1>` (no rewrites; Home copy is P39).
- **D-06** — Headless render/screenshot-pipeline verification; assert breadcrumb ≥2 crumbs + href.
- Plan/wave decomposition, crumb label derivation, presenter-vs-inline helper placement.

## Deferred Ideas

- Audit-row → conversation linking — **Phase 42** (Cross-Screen Threading); not built here.
- `conversation_live` shell / `:reading`-rail migration — **Phase 41**.
- Home body redesign (hero / secondary band / zero-state) — **Phase 39**.
