# Phase 37: Component Primitives - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 37-component-primitives
**Mode:** Advisor / `minimal_decisive` tier. Per `USER-PROFILE.md` decision-handling + `CLAUDE.md`
decision policy, gray areas were **auto-decided with recorded rationale** rather than asked. The
vM016 directions are ratified in `.planning/vM016-UI-ITERATION-BRIEF.md`; requirements UIC-01..05
are locked — only HOW was open. No genuinely VERY-impactful call surfaced; one easily-reversible
choice (hero shape) is flagged in CONTEXT.md for cheap veto.
**Areas decided:** Hero shape, Disclosure mechanism, Switch markup, Status-cell tone source,
Layout utilities scope, Table scroll-wrapper packaging.

---

## Hero shape (UIC-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Separate `cl_hero/1` component | Distinct primitive with `:detail` slot + primary CTA; keeps `cl_stat` strictly numeric | ✓ |
| `cl_stat variant="hero"` + `:detail` slot | Reuses one component via a variant attr | |

**Decision:** Separate `cl_hero/1` (CONTEXT D-02).
**Notes:** A `variant="hero"` would re-polymorphize the exact component D-01 is narrowing, and the
hero has a different anatomy (full-width, ~2–3× weight, primary `cl_button` CTA, detail sub-line).
Flagged for cheap veto — additive public fn, reversible pre-adoption.

---

## Disclosure open-state mechanism (UIC-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Native `<details>` + `phx-update="ignore"`, static initial `open` | SSR/patch-safe; no assigns drive `open`; auto-expand via static HTML attr | ✓ |
| Assigns-bound `open` toggled by `phx-click` | LiveView controls open state | |

**Decision:** Native `<details class="cl-details">`, open state never bound to a server assign
(CONTEXT D-03); reuse existing `.cl-details` CSS.
**Notes:** The 4 conversation PubSub reload handlers (P41) would fight assigns-based open and snap
panels shut. Exact patch-safety guard (`phx-update="ignore"` vs verified static-`open`) deferred to
research; the no-assigns invariant is locked.

---

## Switch markup (UIC-04)

| Option | Description | Selected |
|--------|-------------|----------|
| `<button role="switch" aria-checked>` | Real a11y switch, server-controlled via phx-click | ✓ |
| Styled `<input type="checkbox">` | Form-native checkbox skinned as a toggle | |

**Decision:** Real `role="switch"` button with text label (CONTEXT D-04).
**Notes:** Matches the LiveView settings-toggle idiom and §7.5 never-color-alone (label always
present).

---

## Status-cell tone source (UIC-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Tone-agnostic primitive (`variant` + `label` → `cl_chip`) | Caller supplies tone; mapping added later | ✓ |
| Primitive calls `AuditLogPresenter.action_tone/1` | Bake the audit mapping into the component | |

**Decision:** Tone-agnostic `cl_status_cell` (CONTEXT D-07).
**Notes:** Grounding correction — `action_tone/1` does **not exist** today (presenter only has
`action_label/1`). Building the generic primitive now; the audit-action→tone mapping is wired during
audit-log adoption (P38/P40).

---

## Layout utilities scope (UIC-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Define exactly the 3 named inert utilities | `cl-gap-2`/`cl-align-center`/`cl-justify-between`; keep `.cl-row`/`.cl-stack` preferred | ✓ |
| Introduce a broader utility set | Grow a Tailwind-like layer | |

**Decision:** Define exactly the three named utilities; no framework growth (CONTEXT D-10).
**Notes:** Markup already references the inert names; defining is lower-risk than hunting usages.
Existing `.cl-row`/`.cl-stack` remain the preferred composites (guardrail: minimal `.cl-`
utilities, no Tailwind).

---

## Table scroll-wrapper packaging (UIC-05)

| Option | Description | Selected |
|--------|-------------|----------|
| `.cl-table-scroll` CSS + inline wrapper markup | Wrap existing `.cl-table` instances; no new component | ✓ |
| New `cl_table` wrapper component | Component emits the scroll region + table | |

**Decision:** CSS class + inline wrapper, no new component (CONTEXT D-11).
**Notes:** Tables are hand-authored at varied call sites; a 2-line wrapper per site is lower-risk
than a markup-shape refactor. P43 verifies as responsive acceptance.

---

## Claude's Discretion

- Exact attr names/defaults and slot ordering per component.
- `cl_fact_list` styling reuse (`.cl-details dl/dt/dd`) vs a dedicated `.cl-fact-list`.
- Precise `cl_disclosure` patch-safety guard (invariant locked; mechanism researched).

## Deferred Ideas

- `AuditLogPresenter.action_tone/1` → add during audit-log adoption (P38/P40).
- A `cl_table` wrapper component → reconsider only if call-site count makes inline wrappers
  unwieldy (P43).
- Adoption of primitives into live screens → P38–P45 (P37 stops at built + unit-tested).
