# Phase 12: In-Thread Quick Fix & Ops Closure - Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 10 likely phase files + supporting analogs
**Analogs found:** 10 / 10 likely phase files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/knowledge_automation.ex` | service | request-response/event-driven | `lib/cairnloop/knowledge_automation.ex` | exact |
| `lib/cairnloop/knowledge_automation/article_suggestion.ex` | model | CRUD/request-response | `lib/cairnloop/knowledge_automation/article_suggestion.ex` | exact |
| `lib/cairnloop/knowledge_automation/review_task.ex` | model | CRUD/request-response | `lib/cairnloop/knowledge_automation/review_task.ex` | exact |
| `lib/cairnloop/knowledge_automation/review_task_event.ex` | audit model | event-driven | `lib/cairnloop/knowledge_automation/review_task_event.ex` | exact |
| `lib/cairnloop/web/conversation_live.ex` | LiveView | request-response | `lib/cairnloop/web/conversation_live.ex` | exact |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | LiveView | request-response | `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | exact |
| `lib/cairnloop/web/review_task_presenter.ex` | presenter | transform | `lib/cairnloop/web/review_task_presenter.ex` | exact |
| `lib/cairnloop/web/article_suggestion_presenter.ex` | presenter | transform | `lib/cairnloop/web/article_suggestion_presenter.ex` | exact |
| `lib/cairnloop/knowledge_automation/telemetry.ex` or equivalent | helper | event-driven | `lib/cairnloop/retrieval/telemetry.ex`, `lib/cairnloop/telemetry.ex` | role-match |
| `test/cairnloop/web/conversation_live_test.exs`, `test/cairnloop/knowledge_automation/article_suggestion_test.exs`, `test/cairnloop/retrieval/telemetry_test.exs` | test | liveview/unit | existing same-file tests | exact |

## Pattern Assignments

### `lib/cairnloop/knowledge_automation.ex` (service, request-response/event-driven)

**Primary analog:** `lib/cairnloop/knowledge_automation.ex`

Use the existing command style:

- fetch scoped row,
- prepare attrs or a bounded bundle,
- persist via changeset,
- create or reuse task where needed,
- optionally enqueue existing workers.

Recommended additions:

- `create_or_reuse_conversation_quick_fix/2`
- `get_conversation_quick_fix/2`
- `prepare_quick_fix_package/2`
- `mark_conversation_quick_fix_blocked/3` or equivalent bounded failure helper

Keep these beside existing `suggest_article/2`, `ensure_review_task_for_suggestion/2`, and `create_or_reuse_authoring_article_for_suggestion/2`.

### `lib/cairnloop/knowledge_automation/article_suggestion.ex` (model, CRUD/request-response)

**Primary analog:** `lib/cairnloop/knowledge_automation/article_suggestion.ex`

Relevant existing posture:

- bounded `Ecto.Enum` entrypoint types,
- canonical `evidence_snapshot`,
- `grounding_metadata` map for structured generation state.

Planner guidance:

- Add a conversation entrypoint through the existing enum-based identity pattern.
- Do not loosen canonical citation validation for `evidence_snapshot`.
- Persist thread/assistive quick-fix layers in an explicit typed package under metadata or a neighboring host-owned struct, not in the citation-only embed.

### `lib/cairnloop/web/conversation_live.ex` (LiveView, request-response)

**Primary analog:** `lib/cairnloop/web/conversation_live.ex`

Relevant existing posture:

- evidence rail is already a sequence of self-contained cards,
- draft audit card already renders proposal state + evidence + actions,
- `handle_info/2` reload pattern already exists for durable background updates.

Planner guidance:

- Add one new quick-fix card rather than mutating the draft-audit card.
- Reuse `reload_conversation_with_context/2` plus a new quick-fix query seam so status stays durable and idempotent.
- Follow the existing calm card pattern and keep actions in the rail, not the composer.

### `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` and presenters

**Primary analogs:** `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex`, `lib/cairnloop/web/review_task_presenter.ex`, `lib/cairnloop/web/article_suggestion_presenter.ex`

Relevant existing posture:

- task-centric review lane already renders proposal state, task state, publish outcome, evidence, and history,
- presenters already own label and copy normalization.

Planner guidance:

- Extend presenters for shell/blocked/manual-required quick-fix copy instead of hard-coding strings into LiveViews.
- Reuse the review lane for deep links and quick-fix follow-through rather than adding a second maintenance screen.

### `lib/cairnloop/knowledge_automation/telemetry.ex` or equivalent (helper, event-driven)

**Primary analogs:** `lib/cairnloop/retrieval/telemetry.ex`, `lib/cairnloop/telemetry.ex`

Relevant posture:

- event wrappers normalize measurements and metadata before emission,
- metadata stays low-cardinality and omits raw payloads.

Planner guidance:

- Mirror the retrieval helper pattern for maintenance events.
- Emit coarse fields like `surface`, `entrypoint_type`, `outcome`, `reason`, `publish_status`, `reindex_status`, and small counts.
- Never emit raw thread text, query text, snippets, or citation targets.

## Shared Patterns

### Host-Owned Workflow Truth

Keep durable truth in `ArticleSuggestion`, `ReviewTask`, and `ReviewTaskEvent`, with telemetry as observability only.

### Bounded Operator Copy

Use presenter modules for status labels and next-step copy so thread and review-lane vocabulary remain aligned.

### Canonical-Only Citation Payloads

Leave canonical citation data in `evidence_snapshot`; do not relax that contract just to fit thread context.

## No Analog Found

- There is no existing conversation-scoped KB maintenance card. Phase 12 should borrow layout and loading posture from `draft_audit_card/1`, but it needs its own view model and action seam.

