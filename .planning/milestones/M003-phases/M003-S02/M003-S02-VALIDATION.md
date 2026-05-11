---
phase: M003-S02
slug: dynamic-context-pane-ui-liveview
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-11
---

# Phase M003-S02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Phoenix render/callback tests |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/cairnloop/web/conversation_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/conversation_live_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| M003-S02-01-01 | 01 | 1 | M003-S02 | T-M003-S02-01 | Rail shell always renders and keeps draft actions inside the same evidence surface | render/unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ⬜ pending |
| M003-S02-01-02 | 01 | 1 | S02 | T-M003-S02-02 | Host context is normalized into deterministic sections and unsupported values fall back safely | unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ⬜ pending |
| M003-S02-01-03 | 01 | 1 | S02 | T-M003-S02-03 | Every conversation reload path refreshes both conversation and host context state | callback/unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/conversation_live_test.exs` — add cases for nested section ordering, list rendering, and unsupported-value fallback.
- [ ] `test/cairnloop/web/conversation_live_test.exs` — add callback coverage showing `handle_info/2` and draft/reply actions refresh context along with conversation data.
- [ ] Decide whether endpoint-backed LiveView test scaffolding is needed, since the repo currently relies on direct module tests.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Desktop and narrow-screen rail layout matches the UI contract | M003-S02 | Current repo tests do not exercise responsive CSS/layout behavior | Run the app, open a conversation, verify desktop shows a right rail and narrow width stacks `Customer Context` above `AI Draft / Audit` and above the composer |
| Operator tone, spacing, and card hierarchy feel aligned with the evidence-rail UI spec | M003-S02 | Visual hierarchy is not fully machine-verifiable in current tests | Compare rendered UI against `.planning/phases/M003-S02/M003-S02-UI-SPEC.md` for titles, card order, copy, and shell persistence |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
