---
phase: M009-S02
slug: operator-search-experience
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-17
---

# Phase M009-S02 — Validation Strategy

> Per-phase validation contract for the operator retrieval palette.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/retrieval_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-45 seconds |

## Sampling Rate

- After each search-component task: run `mix test test/cairnloop/web/search_modal_component_test.exs`
- After host-surface integration changes: run `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/conversation_live_test.exs`
- Before phase verification: run `mix test`

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| M009-S02-01-01 | 01 | 1 | M009-REQ-04 | T-M009-S02-01 | Palette uses `Cairnloop.Retrieval` instead of direct remote HTTP search | component | `mix test test/cairnloop/web/search_modal_component_test.exs` | ✅ passed |
| M009-S02-01-02 | 01 | 1 | M009-REQ-05 | T-M009-S02-02 | Results render source/trust labels, fixed sections, and explicit destination metadata | component | `mix test test/cairnloop/web/search_modal_component_test.exs` | ✅ passed |
| M009-S02-02-01 | 02 | 2 | M009-REQ-04 | T-M009-S02-03 | Keyboard navigation, preview-on-focus, and open-on-confirm stay local and deterministic | component | `mix test test/cairnloop/web/search_modal_component_test.exs` | ✅ passed |
| M009-S02-02-02 | 02 | 2 | M009-REQ-04, M009-REQ-05 | T-M009-S02-04 | Inbox, Conversation, and Settings all mount search safely without route-guessing regressions | liveview | `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/settings_live_test.exs` | ✅ passed |

## Reverification Notes

- `M009-S02-VERIFICATION.md` now maps `M009-REQ-04` and `M009-REQ-05` to implementation,
  automated, and manual evidence.
- M009-S05 backfilled the missing `session["host_user_id"]` propagation for Inbox and Settings,
  the scoped-unavailable search state, and the retrieval-boundary proof that filtering happens
  before ranking.
- `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval_test.exs`
  passed on 2026-05-20.
- Test boot still logs existing `Chimeway.Repo` database configuration noise in this workspace,
  but the targeted operator-search suites exit successfully.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Verify resolved-case preview copy does not read like canonical policy | M009-REQ-05 | Trust language quality is partly editorial | Read rendered labels/preview text for one KB hit and one resolved-case hit |
| Verify the desktop vs mobile preview arrangement still feels bounded and clear | M009-REQ-04 | Template structure can pass tests while feeling wrong in practice | Manually inspect the palette layout after implementation |

## Validation Sign-Off

- [x] All tasks have grepable acceptance criteria or automated test commands
- [x] Search component coverage is no longer placeholder-only
- [x] Host-surface tests cover Inbox, Conversation, and Settings
- [x] No verification step depends on remote Scrypath HTTP
- [x] `nyquist_compliant: true` set before completion

**Approval:** verified on 2026-05-20 with S05 closure evidence
