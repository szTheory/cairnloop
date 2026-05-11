---
phase: M003-S02
slug: dynamic-context-pane-ui-liveview
status: draft
shadcn_initialized: false
preset: none
created: 2026-05-11
---

# Phase M003-S02 — UI Design Contract

> Visual and interaction contract for the Dynamic Context Pane in `ConversationLive`. This slice extends Cairnloop's existing audit cockpit into one operator evidence rail.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable |
| Component library | none; Phoenix LiveView function components inside `Cairnloop.Web.ConversationLive` |
| Icon library | none for this slice; rely on text hierarchy and borders instead of icon-first signaling |
| Font | `--cl-font-sans` for all rail UI; `--cl-font-mono` only for machine-like values such as IDs or codes |

---

## Layout Contract

- Desktop (`>= 1024px`): render a two-column conversation shell with the message timeline on the left and one fixed-width evidence rail on the right. Rail width: `352px`. Column gap: `32px`.
- Narrow screens (`< 1024px`): stack the evidence rail directly below the message timeline and above the reply composer. Do not introduce tabs, drawers, or alternate navigation modes.
- Rail order is locked: `Customer Context` card first, `AI Draft / Audit` card second.
- Primary focal point: the operator's eye should land on the top of the `Customer Context` card first, then move downward into the `AI Draft / Audit` actions. The conversation timeline remains the broad reading surface, but the rail is the first evidence anchor.
- The rail shell is always visible, even when context is empty or unavailable.
- Use `24px` internal card padding, `24px` gap between rail cards, and `16px` gap between field rows.
- Use brand radius tokens from `prompts/cairnloop.css`: `14px` for cards, `10px` for buttons, `6px` for compact badges or status pills.

---

## Component Contract

- `context_pane/1`: outer rail wrapper. Apply `--cl-surface` background, `--cl-border` outline, and `--cl-shadow-raised`. The rail should read as one calm evidence surface, not a second app.
- `context_section/1`: card wrapper for `Customer Context` and `AI Draft / Audit`. Title row stays pinned at the top of each card block; keep actions inside the relevant card, not in the rail header.
- `context_field/1`: render normalized scalar data as stacked rows, not tables. Label on top, value below. Use this pattern for readability in a narrow rail.
- `draft_audit_card/1`: preserve existing draft review affordances, but present them as an audit card within the same rail. Action order is `Approve & Send`, `Apply to Composer`, `Discard draft`.
- Nested host context becomes a deterministic section tree:
  - Top-level map keys become section groups.
  - Nested maps become inset subsections with a left border in `--cl-border`.
  - Lists of simple values render as vertical chips or lines, never raw `inspect/1` output.
  - Unsupported values fall back to muted text: `Unsupported value`.

---

## Interaction Contract

- Normalize provider data before render. Sort keys deterministically. Keep host keys as strings internally. Never atomize host-owned keys.
- Render section headings from host-provided top-level strings. Humanize nested field keys when needed for readability (`lifetime_value` -> `Lifetime value`).
- Long values wrap naturally. Never force horizontal scrolling inside the rail.
- Context refreshes every time the conversation is reloaded by a LiveView event or PubSub update. Do not treat mount-time context as authoritative.
- Error in `ContextProvider.get_context/2` only affects the `Customer Context` card. The rest of `ConversationLive` remains usable.
- Empty state and error state live inside the same card shell as success state. Do not collapse or hide the card.
- No modal confirmation for draft discard in this slice. Use an inline confirmation state inside the audit card so the operator keeps timeline context in view.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Hairline offsets, icon/text nudge only |
| sm | 8px | Tight label-to-value spacing, badge padding |
| md | 16px | Default field row spacing |
| lg | 24px | Card padding and card-to-card spacing |
| xl | 32px | Desktop column gap and section separation |
| 2xl | 48px | Major breaks between conversation regions |
| 3xl | 64px | Page-level breathing room when the shell has enough width |

Exceptions: interactive controls must keep a minimum `44px` hit area on narrow screens.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 15px | 400 | 1.6 |
| Label | 13px | 600 | 1.54 |
| Heading | 18px | 600 | 1.44 |
| Display | 28px | 600 | 1.29 |

Use Atkinson Hyperlegible Next for all four roles. Do not use Fraunces in the context rail. Fraunces remains a marketing/display accent, not an operator UI workhorse.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#F5F0E6` (`--cl-bg`) | Page background, conversation shell background |
| Secondary (30%) | `#FBF7EE` (`--cl-surface`) | Evidence rail, cards, reply surface |
| Accent (10%) | `#A94F30` (`--cl-primary`) | Primary action, active rail edge, focus ring, inline link/action emphasis only |
| Destructive | `#B54C36` (`--cl-danger`) | Discard confirmation and context failure state only |

Accent reserved for: `Approve & Send`, active rail marker, keyboard focus, inline action links, and the selected inline confirmation choice. Do not use accent color for all borders, all headings, or all metadata.

Additional semantic use from existing brand tokens:
- `--cl-ai` (`#7A5D78`): small draft/audit metadata accents only.
- `--cl-info` (`#3F6F80`): sourced/retrieval or informational rows only.
- `--cl-success` (`#4A6238`): safe/verified state only.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | Approve & Send |
| Empty state heading | No customer context yet |
| Empty state body | This conversation has no host context to show. Continue with the thread, or reload after host data becomes available. |
| Error state | Customer context is unavailable right now. Continue handling the conversation, then reload to try again. |
| Destructive confirmation | Discard draft: Remove this draft from the rail? This action is recorded and cannot be undone. |

Additional labels locked for this slice:
- Rail card title: `Customer Context`
- Rail card title: `AI Draft / Audit`
- Secondary action label: `Apply to Composer`
- Empty nested section fallback: `No details in this section`

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable - manual Phoenix LiveView stack - 2026-05-11 |
| third-party registries | none | not applicable - 2026-05-11 |

---

## Implementation Notes

- Source decisions already locked upstream:
  - One right-hand evidence rail, not multiple surfaces.
  - Function components, not nested LiveViews or stateful LiveComponents.
  - Deterministic normalized render tree for host context.
  - Always-visible rail shell with explicit empty/error states.
- This slice should visually extend the M002 audit cockpit. The operator should perceive one evidence rail that combines customer context and draft review, not a generic admin sidebar.
- Avoid raw `inspect/1` output in all success states. Every rendered value must look intentional and operator-readable.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
