---
phase: 58
slug: identity-ingress-and-side-effect-trust
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-29
---

# Phase 58 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit from Elixir 1.19.5 with existing Phoenix.ChannelTest, LiveViewTest, Plug.Test, Oban.Testing, and Req.Test patterns |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix ci.fast` |
| **Full suite command** | `mix ci`; add `mix ci.integration` for DB-backed schema or MCP token coverage and `mix ci.quality` for docs/package changes |
| **Estimated runtime** | ~60-180 seconds for focused files; full lanes vary by DB availability |

---

## Sampling Rate

- **After every task commit:** Run the focused test file(s) for the touched trust boundary plus `mix compile --warnings-as-errors`.
- **After every plan wave:** Run `mix ci.fast`.
- **Before `/gsd:verify-work`:** Run `mix ci.fast`; add `mix ci.integration` when DB-backed identity/migration/MCP-token assertions are included; add `mix ci.quality` when docs/package output changes.
- **Max feedback latency:** Prefer focused ExUnit files under 180 seconds before broader lanes.

---

## Per-Requirement Verification Map

| Requirement | Expected Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|--------------------------|-----------|-------------------|-------------|--------|
| TRUST-01 | Widget customer identity is never reused as operator actor for recovery, resolve, approvals, search, or audit context; operator actions use dashboard session actor. | unit + LiveView integration | `mix test test/cairnloop/channels/widget_channel_test.exs test/cairnloop/web/conversation_live_test.exs --warnings-as-errors` | partial | pending |
| TRUST-02 | Missing widget verifier fails closed; explicit demo/test verifier succeeds; no implicit accept-any-token path exists. | socket unit | `mix test test/cairnloop/channels/widget_socket_test.exs --warnings-as-errors` | no | pending |
| TRUST-03 | Email webhook requires configured token/verifier, rejects missing/wrong auth, and halts after unauthorized responses. | plug unit | `mix test test/cairnloop/ingress/email_webhook_plug_test.exs --warnings-as-errors` | yes | pending |
| TRUST-04 | MCP `initialize`, `tools/list`, and `tools/call` fail closed without Bearer token before exposing tool metadata or write surfaces. | router integration | `mix test test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` | yes | pending |
| TRUST-05 | Conversation lifecycle logs and telemetry exclude support message bodies, raw payloads, secrets, arbitrary metadata, and durable-audit-only IDs. | telemetry unit | `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs --warnings-as-errors` | partial | pending |
| OPS-01 | Scrypath/external automation remains inert by default and when explicitly disabled. | application unit | `mix test test/cairnloop/application_test.exs --warnings-as-errors` | yes | pending |
| OPS-02 | Enabled Scrypath with missing or placeholder URL/key does not enqueue work and surfaces a clear configuration failure. | application + worker unit | `mix test test/cairnloop/application_test.exs test/cairnloop/workers/ingest_scrypath_test.exs --warnings-as-errors` | yes | pending |
| OPS-03 | `/health` remains shallow liveness; Doctor reports trust/readiness state without claiming checks it does not perform. | plug + doctor unit | `mix test test/cairnloop/doctor_test.exs test/cairnloop/web/health_plug_test.exs --warnings-as-errors` | partial | pending |
| OPS-04 | Troubleshooting/docs identify whether failures live in host config, DB state, Oban, Cairnloop, or external dependencies. | docs/source scan | `mix test test/cairnloop/docs_trust_test.exs --warnings-as-errors` | no | pending |

---

## Wave 0 Requirements

- [ ] `test/cairnloop/channels/widget_socket_test.exs` - covers TRUST-02 missing verifier, explicit verifier success, and no implicit accept-any-token path.
- [ ] `test/cairnloop/chat_telemetry_test.exs` - covers TRUST-05 negative telemetry keys for conversation resolve/resolved events.
- [ ] `test/cairnloop/web/health_plug_test.exs` - pins shallow `/health` liveness semantics.
- [ ] `test/cairnloop/docs_trust_test.exs` or an existing docs contract test extension - covers MCP token docs, `/health` wording, Scrypath opt-in docs, and doctor/troubleshooting failure-domain truth.
- [ ] If `customer_ref` or another additive customer identity field is added, include schema/migration assertions; mark DB-required tests with `# REPO-UNAVAILABLE` when this workspace cannot run them.

---

## Manual-Only Verifications

All phase behaviors should have automated coverage. Manual verification is limited to reviewing any generated operator-facing prose for calm, reason-forward, fail-closed copy and confirming it does not expose raw support content or secrets.

---

## Validation Sign-Off

- [x] All phase requirements have an automated verification target or Wave 0 dependency.
- [x] Sampling continuity avoids long stretches without focused automated feedback.
- [x] Wave 0 names missing test files needed before feature work proceeds.
- [x] No watch-mode flags are required.
- [x] Feedback latency target is under 180 seconds for focused checks.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending execution
