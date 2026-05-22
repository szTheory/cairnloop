---
phase: M009-S05
slug: search-scope-enforcement-operator-search-closure
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-20
---

# Phase M009-S05 — Validation Strategy

> Per-phase validation contract for search scope enforcement, provider-side filtering, and Phase 2 verification closure.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/retrieval_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-45 seconds |

## Sampling Rate

- After mount or fail-closed search changes: run `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs`
- After provider or retrieval-boundary changes: run `mix test test/cairnloop/retrieval_test.exs`
- After conversation-surface safety changes: run `mix test test/cairnloop/web/conversation_live_test.exs`
- Before phase verification: run `mix test`

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| M009-S05-01-01 | 01 | 1 | M009-REQ-04, M009-REQ-05 | T-M009-S05-01 | Inbox, Settings, and conversation mounts pass explicit scope metadata or fail closed before unsafe retrieval | liveview | `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs` | ✅ passed |
| M009-S05-01-02 | 01 | 1 | M009-REQ-05 | T-M009-S05-02 | Retrieval boundary and providers enforce scope or visibility before `Ranker.merge/3` consumes candidates | unit | `mix test test/cairnloop/retrieval_test.exs` | ✅ passed |
| M009-S05-01-03 | 01 | 1 | M009-REQ-04, M009-REQ-05 | T-M009-S05-03 | Search component distinguishes scoped-unavailable, no-hit, and retrieval-error states without dropping source/trust cues | component | `mix test test/cairnloop/web/search_modal_component_test.exs` | ✅ passed |
| M009-S05-02-01 | 02 | 2 | M009-REQ-04, M009-REQ-05 | T-M009-S05-04 | `M009-S02-VERIFICATION.md` maps each requirement to implementation files, automated evidence, and manual checks | docs | `rg -n 'M009-REQ-04|M009-REQ-05|Implementation evidence|Automated evidence|Manual checks' .planning/milestones/M009-phases/M009-S02/M009-S02-VERIFICATION.md` | ✅ passed |
| M009-S05-02-02 | 02 | 2 | M009-REQ-04, M009-REQ-05 | T-M009-S05-05 | Validation and requirements traceability reflect verified operator-search closure instead of draft-only pending state | docs | `rg -n 'nyquist_compliant|wave_0_complete|M009-REQ-04|M009-REQ-05|Verified|Complete' .planning/milestones/M009-phases/M009-S02/M009-S02-VALIDATION.md .planning/REQUIREMENTS.md` | ✅ passed |

## Wave 0 Requirements

- [x] Add explicit non-conversation scope assertions for Inbox and Settings mounts
- [x] Add retrieval tests that prove filtering decisions happen before ranking merges result sets
- [x] Add search component coverage for scoped-unavailable behavior, not only no-hit and retrieval-error

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm scoped-unavailable copy is calm and makes safety explicit rather than reading like a generic outage | M009-REQ-04, M009-REQ-05 | Editorial trust language can still mislead while tests pass | Render Inbox or Settings without a scoped user and review the search state manually |
| Confirm Knowledge Base remains visually primary over resolved cases after scope-enforcement changes | M009-REQ-05 | Trust ordering is partly qualitative | Run one scoped search with both result types present and inspect labels, section order, and action copy |

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Non-conversation mounts prove scope or fail-closed behavior explicitly
- [x] Retrieval/provider tests prove filtering occurs before ranking
- [x] `M009-S02-VERIFICATION.md` exists with explicit requirement mapping
- [x] `M009-S02-VALIDATION.md` reflects revalidated execution state
- [x] `REQUIREMENTS.md` traceability no longer leaves `M009-REQ-04` and `M009-REQ-05` pending
- [x] `nyquist_compliant: true` set before completion

**Approval:** verified on 2026-05-20
