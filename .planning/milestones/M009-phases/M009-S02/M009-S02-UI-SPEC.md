---
phase: M009-S02
slug: operator-search-experience
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-17
reviewed_at: 2026-05-17
---

# Phase M009-S02 — UI Design Contract

> Visual and interaction contract for the operator retrieval palette in Phoenix LiveView. This slice upgrades the existing `cmd+k` modal into a trustworthy search-and-preview surface for canonical Knowledge Base content and assistive resolved-case evidence.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable |
| Component library | none; Phoenix LiveView component(s) over existing `SearchModalComponent` |
| Icon library | Heroicons or equivalent inline SVG only for source/citation affordances |
| Font | `--cl-font-sans` for all palette UI; `--cl-font-mono` only for exact IDs or timestamps if exposed secondarily |

---

## Layout Contract

- Render one global retrieval palette. Do not introduce source tabs, nested command pages, or a generic launcher.
- Visual focal point is locked: the left-hand results rail and its active row state draw first attention; the right-hand preview pane is secondary confirmation, not the primary visual anchor.
- Desktop (`>= 1120px viewport`): center a two-pane palette shell with `max-width: 1040px`, `min-height: 560px`, and `max-height: 78vh`.
- Desktop pane split is locked:
  - Results rail on the left: `432px` wide.
  - Preview pane on the right: flexible remainder, minimum `480px`.
  - Pane gap: `32px`.
- Tablet and narrow desktop (`768px - 1119px`): keep the same shell, but reduce to `max-width: 92vw` and allow the preview pane to shrink to `420px`.
- Mobile (`< 768px`): stack the palette vertically.
  - Search input remains first.
  - Results list remains second.
  - Preview pane renders below the active result list, not as a separate route or drawer.
- Backdrop uses the existing operator canvas colors with a darkened overlay only strong enough to isolate focus. The palette must still read as part of the same app, not a different product surface.
- Top offset is `64px` on roomy screens and `24px` on compact screens.
- The operator stays inside the current LiveView by default. Preview changes never hard-navigate.

---

## Component Contract

- `search_palette/1`: outer shell. Owns backdrop, focus trap, close behavior, and responsive two-pane layout.
- `search_input/1`: one text input at the top of the palette. Include visible shortcut hint `⌘K` / `Ctrl K` only when the palette is closed elsewhere in the host UI, not inside the active input.
- `results_section/1`: renders exactly two fixed sections in this order:
  - `Knowledge Base`
  - `Similar resolved cases`
- `result_row/1`: balanced evidence row, not a dense debug row and not a sparse link list. Every row must render:
  - source label
  - trust label
  - title
  - concise snippet
  - human-readable recency
  - direct destination action label
- `preview_pane/1`: updates on active-row focus without route churn.
- `preview_header/1`: repeats source label + trust label together, title, and exact destination action.
- `preview_body/1`: source-specific content rules:
  - Knowledge Base preview shows article/revision context, heading, and excerpted body content.
  - Resolved-case preview shows structured assistive evidence blocks in this order: `Issue summary`, `Resolution note`, `Actions taken`, `Outcome`, then citation/backreference summary.
- `preview_footer/1`: action rail. Primary action opens the active result. Secondary metadata may show exact timestamp or citation target, but no raw retrieval score.

---

## Interaction Contract

- Keyboard contract is locked:
  - `cmd/ctrl+k` opens the palette.
  - Open state focuses the input immediately.
  - `ArrowDown` and `ArrowUp` move the active row locally.
  - `Enter` opens the active result.
  - `Cmd/Ctrl+Enter` opens the destination in a new tab/window when the host surface supports it.
  - `Escape` first clears a non-empty query, then closes on the next press.
- Mouse and keyboard must target the same active-row state. Hover may update active styling only if it also updates the same preview state.
- Search queries debounce to the server at `250ms`. Active-row movement never triggers a search request.
- Minimum query length is `2` characters. Empty query state shows section shells with guidance copy instead of stale results.
- Use an accessibility-complete combobox/listbox pattern:
  - input uses combobox semantics
  - results use one listbox with grouped sections
  - active row is announced through `aria-activedescendant`
  - focus remains trapped inside the palette while open
- Do not use global unfiltered `phx-window-keydown` for all typing. Use a bounded client hook or equivalent filtered shortcut binding so normal typing elsewhere in the app is not captured.
- Row activation behavior is source-aware but contract-consistent:
  - Knowledge Base row opens the canonical article destination.
  - Resolved-case row opens the resolved conversation/case destination only on explicit confirm.
  - Both sources preview on focus and open on confirm.
- Preserve operator draft/reply flow inside `ConversationLive`. Opening and closing the palette must not discard composer text, draft state, or the current conversation route.

---

## State Contract

- Initial closed state: no modal shell rendered, only the trigger hook/listener exists.
- Initial open state: empty input, no active result, guidance copy visible in both sections, preview pane shows a neutral instructional state.
- Loading state:
  - keep prior query visible
  - show inline loading treatment in the results rail only
  - do not blank the preview pane if there is already an active result from the current query cycle
- Empty state:
  - show section headers even when both sections are empty
  - distinguish between `no query yet` and `no matches`
- Error state:
  - results rail shows a non-destructive inline error block
  - preview pane falls back to neutral state, not broken markup
- Section-empty state:
  - it is valid for `Knowledge Base` to have results while `Similar resolved cases` is empty, or vice versa
  - each section needs its own small empty message rather than suppressing the section entirely

---

## Result Presentation Rules

- `Knowledge Base` is visually primary:
  - section appears first
  - canonical trust language is stronger and plainer
  - preview action label is `Open article`
- `Similar resolved cases` is assistive:
  - section appears second
  - trust language must explicitly avoid implying policy truth
  - preview action label is `Open resolved case`
- Source and trust labels must appear together in every row and every preview header.
- Recency format is locked:
  - Knowledge Base uses `Updated {relative time}`
  - Resolved cases use `Resolved {relative time}`
  - Exact timestamps may appear secondarily in preview metadata
- Match cues must stay human-readable:
  - examples: `Matches refund policy terms`, `Mentions cancellation window`, `Similar resolution steps`
  - never expose numeric score, percentile, or confidence math
- Snippets are capped to three lines in rows and six lines in preview excerpts before truncation.
- Highlight matched terms with accent treatment, but never let highlighting dominate the row.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Badge interior spacing, highlight inset |
| sm | 8px | Tight metadata gaps, compact action spacing |
| md | 16px | Default row padding, input padding, preview block spacing |
| lg | 24px | Palette shell padding, section padding |
| xl | 32px | Desktop pane gap, major section separation |
| 2xl | 48px | Preview block separation for large content groups |
| 3xl | 64px | Top offset from viewport edge on desktop |

Exceptions: interactive rows and footer actions must preserve a minimum `44px` hit area; no non-token spacing values are allowed elsewhere in the palette contract.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 16px | 400 | 1.5 |
| Label | 14px | 600 | 1.4 |
| Heading | 20px | 600 | 1.3 |
| Display | 28px | 600 | 1.2 |

Use Atkinson Hyperlegible Next for all four roles. Do not introduce display-serif styling in the operator palette.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#F5F0E6` (`--cl-bg`) | Backdrop-adjacent canvas, surrounding application shell |
| Secondary (30%) | `#FBF7EE` (`--cl-surface`) | Palette shell, result rows, preview cards, section bodies |
| Accent (10%) | `#A94F30` (`--cl-primary`) | Active row edge, focus ring, matched-term highlight, primary open action only |
| Destructive | `#B54C36` (`--cl-danger`) | Error emphasis only when the search service fails |

Accent reserved for: active result marker, keyboard focus outline, inline matched-term highlight, and the primary `Open article` / `Open resolved case` action. Do not use accent color for every badge, heading, or border.

Additional semantic use from existing operator tokens:
- `--cl-info` (`#3F6F80`) may support assistive-evidence badges and citation metadata.
- `--cl-success` (`#4A6238`) may support canonical-source badges.
- Semantic colors are supplemental only. Source/trust meaning must remain explicit in text.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | Open result |
| Empty state heading | Search knowledge and past resolutions |
| Empty state body | Type at least 2 characters to search the Knowledge Base first, then similar resolved cases for supporting evidence. |
| Error state | Search is unavailable right now. Keep working in the current conversation, then try the search again. |
| Destructive confirmation | none: none |

Additional labels locked for this slice:
- Input placeholder: `Search knowledge and resolved cases`
- Section heading: `Knowledge Base`
- Section heading: `Similar resolved cases`
- Canonical trust label: `Canonical guidance`
- Assistive trust label: `Supporting evidence`
- Section-empty copy for KB: `No knowledge base matches for this query.`
- Section-empty copy for cases: `No similar resolved cases for this query.`
- Neutral preview heading: `Preview results here`
- Neutral preview body: `Move through results to inspect source details before you open anything.`

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable - manual Phoenix LiveView stack - 2026-05-17 |
| third-party registries | none | not applicable - 2026-05-17 |

---

## Implementation Notes

- Pre-populated from upstream:
  - One palette, two fixed sections, preview-on-focus, and open-on-confirm come from `M009-S02-CONTEXT.md`.
  - Retrieval source/trust semantics come from `M009-S01-RESEARCH.md` and `lib/cairnloop/retrieval/result.ex`.
  - Existing operator token direction comes from `M003-S02-UI-SPEC.md`.
- Replace direct Scrypath HTTP calls in [`lib/cairnloop/web/search_modal_component.ex`](/Users/jon/projects/cairnloop/lib/cairnloop/web/search_modal_component.ex:1) with the internal retrieval boundary in [`lib/cairnloop/retrieval.ex`](/Users/jon/projects/cairnloop/lib/cairnloop/retrieval.ex:1).
- Keep one normalized presenter over `Cairnloop.Retrieval.Result`; do not create a second search-only payload shape.
- The preview pane is part of the same palette shell, not a second modal and not a route transition.
- The palette should feel calm and operator-grade. Avoid launcher theatrics, command nesting, debug-density metadata, or AI-chat metaphors.

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-05-17
