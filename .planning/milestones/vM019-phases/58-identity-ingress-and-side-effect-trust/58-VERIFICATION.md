---
phase: 58-identity-ingress-and-side-effect-trust
verified: 2026-06-30T04:46:32Z
status: passed
score: 13/13 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 58: Identity, Ingress, and Side-Effect Trust Verification Report

**Phase Goal:** Make Cairnloop fail closed around customer/operator identity, inbound auth, sensitive logs,
telemetry metadata, and optional side effects.
**Verified:** 2026-06-30T04:46:32Z
**Status:** passed
**Re-verification:** No - initial verification.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Customer/browser identity is no longer reused as operator identity for recovery, resolve, approvals, search, context lookup, quick-fix, or audit actions. | VERIFIED | `Conversation.customer_ref` exists and is cast separately from `host_user_id` (`lib/cairnloop/conversation.ex:10-25`). `Chat.create_customer_conversation/1` maps `customer_ref` or legacy customer-token `host_user_id` into `customer_ref` and leaves `host_user_id` to explicit `operator_host_user_id` only (`lib/cairnloop/chat.ex:66-76`). `ConversationLive` assigns `operator_host_user_id` from dashboard session and uses `with_operator_actor/2` for quick-fix, resolve, propose, approve, reject, defer, and manual-draft paths (`lib/cairnloop/web/conversation_live.ex:30`, `137-165`, `182-233`, `280-397`, `1753-1779`). |
| 2 | Customer identity persistence is additive and install/migration paths create `customer_ref`. | VERIFIED | Installer, test-host migration, and example-app migration all add nullable `customer_ref` beside `host_user_id` (`lib/mix/tasks/cairnloop/install.ex:61-62`, `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs:15-16`, `examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs:8-9`). Source-scan tests pin this (`test/cairnloop/tasks/install_test.exs:42-67`). |
| 3 | Widget ingress has an explicit host-verification seam and production-safe fail-closed default. | VERIFIED | `Cairnloop.Widget.Verifier` defines `verify/2`; `FailClosed.verify/2` rejects; `WidgetSocket.connect/3` resolves `:widget_token_verifier`, loads the configured verifier, and rejects missing/invalid verifier configs (`lib/cairnloop/widget/verifier.ex`, `lib/cairnloop/widget/verifier/fail_closed.ex`, `lib/cairnloop/channels/widget_socket.ex:8-47`). Example dev/test configs explicitly opt into the demo verifier. |
| 4 | Widget joins route verified customer identity to `customer_ref`, never operator identity. | VERIFIED | `WidgetChannel.join/3` requires `socket.assigns[:customer_ref]` and calls `Chat.create_customer_conversation(%{customer_ref: customer_ref})`; missing `customer_ref` returns unauthorized (`lib/cairnloop/channels/widget_channel.ex:10-22`, `39-44`). Tests assert created conversations have `customer_ref` and nil `host_user_id` (`test/cairnloop/channels/widget_channel_test.exs:75-93`). |
| 5 | Email webhook ingress authenticates before unsafe parse/enqueue and has no literal default secret. | VERIFIED | `EmailWebhookVerifier.verify/1` fails closed without host verifier/token and validates shared token securely (`lib/cairnloop/ingress/email_webhook_verifier.ex:13-44`, `121-143`). `EmailWebhookPlug.call/2` invokes `read_verified_body/1` before JSON decode/enqueue and returns halted 401 on unauthorized (`lib/cairnloop/ingress/email_webhook_plug.ex:8-32`, `35-59`). Unauthorized tests use an exploding body adapter and flunking enqueue function to prove no body read/enqueue on rejection (`test/cairnloop/ingress/email_webhook_plug_test.exs:11-18`, `62-88`, `197`). |
| 6 | MCP `initialize`, `tools/list`, and `tools/call` fail closed before capability/tool metadata or write surfaces without a valid Bearer token. | VERIFIED | `Router.call/2` runs `AuthPlug`, parses method, then checks `token_required_method?/1` before dispatch (`lib/cairnloop/web/mcp/router.ex:48-58`, `70-73`). Unauthorized responses set `WWW-Authenticate: Bearer` and halt (`lib/cairnloop/web/mcp/router.ex:182-188`). Tests cover missing/invalid token for initialize/list/call without metadata exposure (`test/cairnloop/web/mcp/router_test.exs:59-68`, `93-156`, `223-260`). |
| 7 | Optional Scrypath/external automation is inert by default and when explicitly disabled. | VERIFIED | `ScrypathConfig.status/1` returns `:disabled` unless `:scrypath_automation_enabled` is exactly true (`lib/cairnloop/scrypath_config.ex:21-38`). The application only attaches optional telemetry when Scrypath is ready and `handle_conversation_resolved/4` returns `:ok` for disabled state (`lib/cairnloop/application.ex:27-46`). Tests cover default and explicit false inert behavior (`test/cairnloop/application_test.exs:18-40`). |
| 8 | Enabled Scrypath with missing or unsafe default URL/key does not enqueue work or issue HTTP. | VERIFIED | `ScrypathConfig.status/1` returns bounded atom reasons for missing or placeholder URL/key (`lib/cairnloop/scrypath_config.ex:53-64`). Application bridge skips enqueue on misconfiguration (`lib/cairnloop/application.ex:42-46`). Worker discards disabled/misconfigured jobs before `Req.post/2` (`lib/cairnloop/workers/ingest_scrypath.ex:5-18`). Tests assert no enqueue/HTTP under disabled and misconfigured configs (`test/cairnloop/application_test.exs:42-60`, `test/cairnloop/workers/ingest_scrypath_test.exs:109-147`). |
| 9 | Ready Scrypath side effects enqueue only a durable pointer and fetch content inside the enabled worker path. | VERIFIED | Bridge enqueues only `%{"conversation_id" => conversation_id}` (`lib/cairnloop/application.ex:49-63`). Worker builds outbound payload from `Chat.get_conversation!/1` after ready config validation (`lib/cairnloop/workers/ingest_scrypath.ex:20-56`). Tests pass metadata containing raw support body but assert queued args contain only `conversation_id`, then assert ready worker ignores job text and uses durable conversation data (`test/cairnloop/application_test.exs:63-85`, `test/cairnloop/workers/ingest_scrypath_test.exs:149-190`). |
| 10 | Logs and conversation telemetry exclude support bodies, raw payloads, secrets, arbitrary metadata, host/customer/operator IDs, and full structs by default. | VERIFIED | `conversation_resolve_metadata/2` emits only `conversation_id`, `operation`, and optional `outcome` (`lib/cairnloop/chat.ex:351-360`). `ProcessMessage` email branch logs static text only (`lib/cairnloop/workers/process_message.ex:52-62`). Negative tests assert forbidden keys and sensitive strings are absent from telemetry/logs (`test/cairnloop/chat_telemetry_test.exs:12-28`, `94-156`; `test/cairnloop/workers/process_message_test.exs:58-78`). |
| 11 | `/health` remains shallow liveness and does not claim readiness. | VERIFIED | `HealthPlug` returns only `{"status":"ok"}` and documents DB/Oban/pgvector/notifier/ingress/MCP/Scrypath checks are not performed there (`lib/cairnloop/web/health_plug.ex:1-22`). Health tests assert no readiness/dependency fields (`test/cairnloop/web/health_plug_test.exs:8-38`). |
| 12 | Doctor output exposes trust/readiness posture honestly without leaking secrets or overclaiming checks. | VERIFIED | `Doctor.checks/2` covers repo, dashboard/operations routes, widget verifier, email auth, MCP token method posture, notifier, Oban, pgvector, and Scrypath states (`lib/cairnloop/doctor.ex:40-68`, `173-244`, `278-312`). Messages use Ready/Blocked/Not checked here and do not print tokens, URL credentials, or API keys; tests assert this (`test/cairnloop/doctor_test.exs:114-201`). |
| 13 | Targeted host-integration/troubleshooting/MCP docs expose operational state and safe defaults without sensitive content. | VERIFIED | MCP guide names `Cairnloop.Web.MCP.AuthPlug`, opaque raw Bearer tokens, public well-known discovery only, and 401 fail-closed method behavior (`guides/05-mcp-clients.md:11-33`, `74-80`). Host integration and troubleshooting docs describe `/health` liveness only, doctor, Scrypath opt-in/no-enqueue states, failure domains, and bounded telemetry (`guides/03-host-integration.md:264-390`, `guides/04-troubleshooting.md:177-258`). Source-scan tests pin these claims (`test/cairnloop/docs_trust_test.exs:20-110`). |

**Score:** 13/13 truths verified (0 present-but-behavior-unverified).

### Required Artifacts

| Artifact Group | Expected | Status | Details |
|---|---|---|---|
| 58-01 identity persistence | `conversation.ex`, `chat.ex`, installer, test-host/example migrations, chat/install tests | VERIFIED | `gsd-tools verify.artifacts` passed 7/7; manual inspection confirmed `customer_ref` field, cast, migration parity, and compatibility mapping. |
| 58-02 widget verifier | verifier behaviour/default/demo, socket/channel, example config, socket/channel tests | VERIFIED | `gsd-tools verify.artifacts` passed 9/9; manual inspection confirmed fail-closed default and verified `customer_ref` join routing. |
| 58-03 operator identity | `ConversationLive` and tests | VERIFIED | `gsd-tools verify.artifacts` passed 2/2; manual inspection confirmed session actor assignment, mutation guards, and missing-identity trust-state UI. |
| 58-04 email/MCP ingress | webhook verifier/plug, MCP router/docs/tests | VERIFIED | `gsd-tools verify.artifacts` passed 7/7; manual inspection confirmed auth before parse/enqueue and token-required MCP method gate. |
| 58-05 Scrypath side effects | Scrypath config, application bridge, worker, tests | VERIFIED | `gsd-tools verify.artifacts` passed 5/5; manual inspection confirmed disabled/misconfigured no-enqueue/no-HTTP and ready-only worker path. |
| 58-06 telemetry/logging | bounded chat telemetry, telemetry docs, process-message log tests | VERIFIED | `gsd-tools verify.artifacts` passed 4/4; manual inspection confirmed bounded metadata helper and static default email warning. |
| 58-07 doctor/health/docs | doctor, doctor task, health plug, host/troubleshooting docs, tests | VERIFIED | `gsd-tools verify.artifacts` passed 8/8; manual inspection confirmed liveness-only health and doctor/trust docs. |

### Key Link Verification

| Link | Status | Details |
|---|---|---|
| Chat -> Conversation `customer_ref` changeset | VERIFIED | `gsd-tools verify.key-links` passed; code maps customer identity into `Conversation.changeset/2` with `customer_ref`. |
| WidgetSocket -> Widget verifier -> WidgetChannel -> Chat | VERIFIED | `gsd-tools verify.key-links` passed; socket calls configured verifier, channel requires `customer_ref`, Chat persists it. |
| Router session -> ConversationLive operator actor -> Chat/Governance/Outbound/KnowledgeAutomation | VERIFIED | `ConversationLive` derives `operator_host_user_id` from session and all planned operator paths use `operator_actor/1` or `with_operator_actor/2`. |
| EmailWebhookPlug -> EmailWebhookVerifier before read/parse/enqueue | VERIFIED | Plug verifies first for non-body verifiers and supports raw-body verifier path with a single body owner. Unauthorized requests halt before enqueue. |
| MCP Router -> AuthPlug -> token-required dispatch | VERIFIED | Router runs `AuthPlug`, checks `mcp_token`, and gates `initialize`, `tools/list`, and `tools/call`. |
| Application Scrypath bridge -> ScrypathConfig -> IngestScrypath worker | VERIFIED | Bridge and worker both use `ScrypathConfig.status/1`; bridge enqueues `conversation_id` only; worker fetches durable data. |
| Chat telemetry -> Application side-effect bridge | VERIFIED | `[:conversation, :resolved]` metadata retains `conversation_id` only as the side-effect pointer. |
| Doctor/docs -> implemented trust checks | VERIFIED | Doctor reports widget/email/MCP/Scrypath states; docs and source-scan tests describe the same behavior. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `WidgetChannel.join/3` | `customer_ref` | `WidgetSocket.connect/3` assigns verifier result | Yes - explicit verifier returns bounded `customer_ref`; missing value rejects | FLOWING |
| `ConversationLive` | `operator_host_user_id` | dashboard LiveView session `host_user_id` | Yes - session value is normalized and used for context, search, quick-fix, resolve, recovery, governance | FLOWING |
| `EmailWebhookPlug` | body/enqueue changeset | verified request only | Yes - valid token/verifier permits parse and enqueue; unauthorized path never reads/enqueues for non-body verifiers | FLOWING |
| `MCP.Router` | `conn.assigns.mcp_token` | `AuthPlug` validates persisted token hash through `Cairnloop.MCP.validate_token/1` | Yes - valid token exposes metadata/write path; invalid/missing token halts with 401 | FLOWING |
| Scrypath bridge/worker | `conversation_id` | bounded telemetry metadata, then durable conversation fetch | Yes - bridge uses only ID; worker fetches conversation and messages after ready config | FLOWING |
| Doctor/docs | config findings | injected/application config and router routes | Yes - reports concrete local posture and labels non-queried dependencies as not checked here | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Phase 58 focused behavior tests | `mix test test/cairnloop/chat_test.exs test/cairnloop/channels/widget_socket_test.exs test/cairnloop/channels/widget_channel_test.exs test/cairnloop/ingress/email_webhook_plug_test.exs test/cairnloop/web/mcp/auth_plug_test.exs test/cairnloop/web/mcp/router_test.exs test/cairnloop/application_test.exs test/cairnloop/workers/ingest_scrypath_test.exs test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs test/cairnloop/doctor_test.exs test/cairnloop/web/health_plug_test.exs test/cairnloop/docs_trust_test.exs test/cairnloop/web/conversation_live_test.exs --warnings-as-errors` | 185 tests, 0 failures, 14 excluded | PASS |
| Warnings-clean compile | `mix compile --warnings-as-errors` | exit 0 | PASS |
| UI guard suite | `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/responsive_markup_test.exs test/cairnloop/web/motion_css_test.exs --warnings-as-errors` | 62 tests, 0 failures | PASS |
| Current orchestrator gates after final fixes | `mix ci.fast`; `mix ci.quality`; focused webhook and ConversationLive tests | User/orchestrator reported `mix ci.fast` passed with 1146 tests, 0 failures, 62 excluded; `mix ci.quality` passed; focused suites passed | PASS (reported current gate) |

### Probe Execution

Step 7c: SKIPPED. No Phase 58 plan/summary declares probe scripts, and `find scripts -path '*/tests/probe-*.sh'` returned no conventional probes.

### Requirements Coverage

| Requirement | Source Plan(s) | Status | Evidence |
|---|---|---|---|
| TRUST-01 | 58-01, 58-02, 58-03 | SATISFIED | `customer_ref` persistence, widget join routing, and ConversationLive session actor guards all verified with tests and code inspection. |
| TRUST-02 | 58-02 | SATISFIED | Widget verifier seam, fail-closed default, explicit demo config, and socket/channel tests verified. |
| TRUST-03 | 58-04 | SATISFIED | Email webhook verifier/token seam, no literal default secret, halted unauthorized path before body/enqueue for non-body verifiers, and tests verified. |
| TRUST-04 | 58-04 | SATISFIED | MCP token-required methods gate `initialize`, `tools/list`, and `tools/call`; docs and tests verified. |
| TRUST-05 | 58-06 | SATISFIED | Bounded telemetry metadata and static default email warning verified by negative tests. |
| OPS-01 | 58-05, 58-07 | SATISFIED | Scrypath disabled by default/explicit false; doctor/docs show disabled as inert. |
| OPS-02 | 58-05, 58-07 | SATISFIED | Enabled but missing/placeholder Scrypath URL/key blocks enqueue/HTTP and doctor/docs report bounded reasons. |
| OPS-03 | 58-07 | SATISFIED | `/health` is liveness-only; doctor owns readiness/trust diagnostics; no required readiness endpoint added. |
| OPS-04 | 58-04, 58-07 | SATISFIED | MCP/email troubleshooting truth, doctor failure domains, bounded telemetry docs, and targeted source-scan tests verified. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| None | - | `TBD/FIXME/XXX`, placeholder/stub markers, hardcoded empty rendered props, and console/debug-only implementations | None | Phase-touched files scanned clean. |

### Deferred / Non-Blocking Items

- `mix ci.integration` is not a hidden success. `deferred-items.md` records repeated failure with 18 LiveView-heavy integration failures in existing inbox/governance/widget paths, outside the customer-ref, email/MCP, and widget-channel assertions introduced by Phase 58. Plan 02 notes the widget-channel integration case fails before channel join at `live(conn, "/inbox")`.
- Earlier `mix ci.fast` failures in Plans 03 and 06 were formatter-only dirty-worktree issues in `ConversationLive`; `deferred-items.md` records a Wave 2 orchestrator follow-up where `mix format --check-formatted lib/cairnloop/web/conversation_live.ex && mix compile --warnings-as-errors && mix ci.fast` passed.
- Broad host-integration docs still contain older ContextProvider wording that says `actor_id` is the raw string from the Cairnloop conversation (`guides/03-host-integration.md:33`). Runtime code now passes the dashboard session actor. This is not a Phase 58 blocker because Phase 58 targeted operational trust docs, while Phase 60 explicitly owns broad host-integration/docs truth.

### Human Verification Required

None. All behavior-dependent truths have focused automated tests that passed locally or were covered by the current orchestrator gate report.

### Gaps Summary

No blocking Phase 58 gaps found. The implementation satisfies the phase goal and plan objectives. The known integration lane remains a documented pre-existing/deferred failure, not evidence of hidden Phase 58 success.

---

_Verified: 2026-06-30T04:46:32Z_
_Verifier: the agent (gsd-verifier)_
