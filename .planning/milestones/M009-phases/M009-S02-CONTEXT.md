# M009-S02 Context: Operator Search Experience

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn the Phase 1 retrieval layer into a trustworthy keyboard-first operator workflow inside the LiveView dashboard. This phase covers the `cmd+k` search interaction model, result organization, preview/navigation behavior, and result presentation for Knowledge Base content plus similar resolved cases. It does not cover grounded drafting UX, citation rendering inside draft review, retrieval telemetry dashboards, or generic command-runner features beyond search-and-open.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Shift decision burden left within GSD for Cairnloop. Downstream agents should make strong, coherent defaults aligned with product posture, ecosystem idioms, and existing architecture instead of escalating every gray area.
- **D-02:** Re-escalate only when a decision materially changes scope, trust semantics, or Cairnloop's product posture.
- **D-03:** Principle of least surprise beats novelty. Prefer a calm, operator-grade search workflow over a clever or maximalist command system.

### Result organization
- **D-04:** Use one global `cmd+k` search surface and one query flow, not separate tabs or separate modals for each source type.
- **D-05:** Organize results into fixed source-aware sections inside the same palette: `Knowledge Base` first, `Similar resolved cases` second.
- **D-06:** Do not ship a fully mixed cross-source list as the default experience, even if raw relevance scores would occasionally support it.
- **D-07:** Within each section, rank by relevance using the retrieval backend; the UI must not re-rank results client-side.
- **D-08:** Keep canonical Knowledge Base content visually and semantically primary over assistive resolved-case evidence.
- **D-09:** Strong per-row source labels, recency, and concise match cues are required so section boundaries are not the only trust signal.

### Result destination and preview behavior
- **D-10:** Use a preview-on-focus, open-on-confirm model for the palette rather than immediate hard navigation on selection.
- **D-11:** Moving the active selection should update an inline preview pane while keeping the operator in the current LiveView until they explicitly open a result.
- **D-12:** Knowledge Base hits are canonical destinations and should support fast open after preview.
- **D-13:** Resolved-case hits are assistive evidence and must surface a structured preview with citations before full navigation.
- **D-14:** `Enter` opens the active result destination; `Cmd/Ctrl+Enter` may open a full-page destination in a new tab/window if supported by the host surface.
- **D-15:** Result behavior may differ by source type in what the preview contains, but the keyboard contract must stay consistent across sources.
- **D-16:** Avoid host-app-specific route guessing inside the modal. Result structs should resolve to explicit internal destinations or explicit preview-only states.
- **D-17:** Preserve operator session context by default, especially inside `ConversationLive`; avoid navigation patterns that can silently discard reply or draft state.

### Keyboard interaction model
- **D-18:** Upgrade the current modal into a rich-but-bounded retrieval-first command palette rather than keeping a typing-and-click-only search box.
- **D-19:** Required baseline interactions: `cmd/ctrl+k` opens, input focuses immediately, `ArrowUp/ArrowDown` move the active row, `Enter` opens, and `Escape` clears then closes.
- **D-20:** Mouse behavior must mirror keyboard state rather than creating a second interaction model.
- **D-21:** Keep the palette scoped to search-and-open behavior for M009. Defer nested command pages, multi-step actions, and generic action-launcher behavior.
- **D-22:** Search queries should hit the server on debounce; active-row movement must not require a retrieval round-trip per keypress.
- **D-23:** Treat the palette as an accessibility-complete combobox/listbox pattern with proper focus trapping and visible active selection.
- **D-24:** Do not keep the current unfiltered `phx-window-keydown` approach as the long-term event model; shortcut handling must avoid noisy server traffic and accidental capture while typing elsewhere.

### Result density and trust signals
- **D-25:** Use a balanced evidence-first result row, not a sparse title/snippet list and not an over-dense debug row.
- **D-26:** Always visible on each row: source type, trust label, title, snippet, recency, and a direct citation/open-source action.
- **D-27:** Keep exact citation payload details, expanded match reasons, and debug metadata secondary rather than always in-row.
- **D-28:** Source label and trust label must appear together; do not rely on color alone or on trust language without source context.
- **D-29:** Recency must be visible in human scanning form, such as `Updated 12d ago` or `Resolved 3mo ago`, with exact timestamps available secondarily if needed.
- **D-30:** Hide raw numeric scores from operators. Ranking explanations should use human-readable cues rather than fake precision.
- **D-31:** Resolved-case snippets must not read like policy truth. Keep assistive evidence distinct from canonical article content.

### Library and architecture alignment
- **D-32:** Route operator search through `Cairnloop.Retrieval` and normalized result contracts, not direct remote HTTP calls from UI components.
- **D-33:** Keep one normalized UI presenter over `Cairnloop.Retrieval.Result`; do not invent a separate ad hoc search-only payload model.
- **D-34:** Render source/trust badges from enums or constrained values, not freeform strings.
- **D-35:** Use server-owned ranking truth and result semantics so LiveView rendering, drafting reuse, and future telemetry all share one paved-road contract.

### the agent's Discretion
- Exact placement of the preview pane on desktop vs compact layouts
- Exact empty-state copy for section-specific no-hit cases
- Exact wording of match cues and citation action labels
- Whether to support a small pinned `Best knowledge match` treatment when a canonical hit clearly wins
- Whether lightweight source query prefixes like `kb ` or `case ` are introduced in a later follow-on task rather than this phase

</decisions>

<specifics>
## Specific Ideas

- The palette should feel like search for grounded evidence, not a chat input and not a generic app launcher.
- Borrow the muscle memory of strong command palettes, but keep the scope narrow and boring on purpose.
- The most important trust distinction must remain obvious everywhere: `Knowledge Base` is canonical truth; `Similar resolved case` is supporting evidence.
- Keep operators in flow. Preview before route churn, especially when they are already inside a live conversation.
- Make source verification close to the result rather than hidden behind a second workflow.
- Apply the same shift-left preference used in Phase 1: downstream agents should recommend cohesive defaults instead of turning every UX detail into a user poll.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements and posture
- `.planning/M009-ROADMAP.md` — Phase 2 goal, requirements, success criteria, and milestone boundary
- `.planning/PROJECT.md` — Current product posture and milestone framing
- `.planning/REQUIREMENTS.md` — M009 requirement mapping and non-goals
- `.planning/STATE.md` — Current milestone state and accumulated architectural decisions
- `.planning/MILESTONE-ARC.md` — Strategic ordering and explicit retrieval-first priorities
- `.planning/PROJECT_EPICS.md` — Epic-level product direction and support/search philosophy

### Prior phase decisions
- `.planning/milestones/M009-phases/M009-S01-CONTEXT.md` — Locked retrieval semantics, source hierarchy, and trust boundary from Phase 1
- `.planning/milestones/M009-phases/M009-S01/M009-S01-RESEARCH.md` — Retrieval architecture and result-contract research backing the Phase 1 boundary

### Existing search UI contract and prior implementation
- `.planning/phases/3/03-UI-SPEC.md` — Existing visual and interaction contract for the earlier `cmd+k` search surface
- `.planning/phases/3/RESEARCH.md` — Prior LiveView-specific keyboard/search research and pitfalls
- `.planning/phases/3/03-01-SUMMARY.md` — Summary of the current search modal implementation and its limitations

### Product and ecosystem direction
- `prompts/cairnloop_brand_book.md` — Brand and product posture: host-owned, sourced, calm, explicit trust, operator-grade reliability
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Market and product lessons from adjacent tools and what Cairnloop should emulate vs avoid
- `prompts/scoria overview for integration ideas.txt` — Guidance for inspectable retrieval, explainability, and future trace/eval interoperability
- `prompts/parapet overview for integration ideas.txt` — Telemetry contract and operator-safety principles relevant to future retrieval/search instrumentation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/retrieval.ex` — Internal retrieval facade already exists and should become the paved-road caller for operator search
- `lib/cairnloop/retrieval/result.ex` — Normalized result struct already exposes source, trust, citation, and match-reason fields that support this phase directly
- `lib/cairnloop/retrieval/ranker.ex` — Server-owned ranking/explainability baseline that should remain authoritative for UI ordering
- `lib/cairnloop/web/search_modal_component.ex` — Existing global search modal provides the mounting point, but currently uses direct HTTP and a thinner interaction model
- `lib/cairnloop/web/inbox_live.ex`, `lib/cairnloop/web/conversation_live.ex`, `lib/cairnloop/web/settings_live.ex` — Existing LiveView surfaces where a consistent palette experience must work

### Established Patterns
- One internal retrieval boundary is preferred over UI-specific transport logic
- Trust semantics are explicit in the result contract: canonical KB truth vs assistive resolved-case evidence
- LiveView components are reused across multiple operator surfaces rather than rebuilt per page
- Cairnloop favors calm, operator-grade workflows over flashy AI- or action-launcher metaphors

### Integration Points
- Replace the direct remote search call in `lib/cairnloop/web/search_modal_component.ex` with `Cairnloop.Retrieval` usage
- Introduce preview-capable result presentation without breaking the normalized `Retrieval.Result` contract that later drafting features will reuse
- Preserve `ConversationLive` editing context when search is opened from a conversation thread
- Add meaningful keyboard/accessibility tests where current coverage is only skeletal

</code_context>

<deferred>
## Deferred Ideas

- Generic command-runner behavior, nested command pages, or action-launcher semantics beyond retrieval search
- Source query prefixes or advanced filter syntax unless planning determines they are nearly free and low-risk
- Fully expanded debug-density result rows for operator-facing search; use richer density later in eval/debug views instead
- Draft citation rendering and weak-grounding escalation UX, which belong to M009 Phase 3
- Retrieval quality telemetry views and no-hit analysis surfaces, which belong to M009 Phase 4

</deferred>

---

*Phase: M009-S02*
*Context gathered: 2026-05-17*
