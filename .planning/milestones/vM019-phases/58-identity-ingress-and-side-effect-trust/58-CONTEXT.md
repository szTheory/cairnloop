# Phase 58: Identity, Ingress, and Side-Effect Trust - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Harden Cairnloop's existing trust boundaries around browser/customer identity, operator identity,
widget ingress, email webhook ingress, MCP auth, sensitive logs/telemetry, optional Scrypath side
effects, and operational doctor/readiness truth.

This phase is not a new product-surface phase. Do not add customer-support workflows, rich email
handling, routing features, local AI, hosted demo work, or a Cairnloop-owned auth system. The work
is to make existing seams fail closed, document their host-owned contracts, and add targeted tests.

</domain>

<decisions>
## Implementation Decisions

### Identity Boundaries

- **D-01:** Treat `host_user_id` as operator/governance identity only. Widget/customer/session
  identity must not be persisted or reused as the operator actor for recovery, resolve, approvals,
  search, audit context, or governed actions.
- **D-02:** Add an explicit host-configured widget verifier seam for browser/customer tokens. The
  default production posture is fail closed when no verifier is configured. Demo/dev/test flows may
  use an explicit demo verifier or explicit config, but not an implicit "accept any string" path.
- **D-03:** An additive persistence change is allowed in this phase if needed to separate customer
  identity from operator identity. Preserve existing public API shape where feasible and avoid
  repurposing `Conversation.host_user_id` for customer/session tokens.

### Ingress Auth

- **D-04:** Email webhook ingress stays narrow in this phase: authenticate the request, parse enough
  to preserve the existing queued email stub, and fail closed when no host token/signature verifier
  is configured. Full email-to-conversation product behavior remains out of scope.
- **D-05:** Keep the current no-literal-default-secret posture. If the planner expands the seam, prefer
  a small verifier behaviour/callback or configured token/signature function over provider-specific
  webhook product work.
- **D-06:** MCP JSON-RPC endpoints must not expose configured tool metadata or write surfaces without
  a valid Bearer token. `tools/list` and `tools/call` are protected; `initialize` should also be
  token-required unless research finds a spec reason to return a minimal unauthenticated handshake
  with no tool metadata. The well-known OAuth/resource metadata endpoint may remain public for client
  discovery.

### Sensitive Logs and Telemetry

- **D-07:** Default logs and telemetry must exclude support message bodies, raw email payloads,
  secrets, arbitrary request payloads, and unbounded host/customer metadata. IDs that belong in
  durable DB/audit rows should not become metric labels or generic telemetry metadata.
- **D-08:** Conversation lifecycle telemetry should follow the existing retrieval/governance/outbound
  bounded-metadata pattern. Any optional Scrypath/export bridge should fetch durable data inside its
  enabled worker path rather than relying on raw support content in generic telemetry metadata.
- **D-09:** Tests should reject raw body keys and arbitrary metadata in default logs/telemetry. Keep
  diagnostic detail behind explicit opt-in diagnostics, never as the default production posture.

### Optional Side Effects

- **D-10:** Scrypath/external automation is opt-in only. The existing default-disabled config posture
  is the right direction; planning should make it explicit, documented, doctor-visible, and covered by
  regression tests.
- **D-11:** When Scrypath automation is enabled, dummy/default API credentials are invalid. Missing or
  placeholder `:scrypath_api_url` / `:scrypath_api_key` should produce a clear doctor/strict failure,
  and the application must not enqueue work with unsafe defaults.
- **D-12:** Do not broaden side-effect machinery. Keep this phase focused on gating the existing
  `[:cairnloop, :conversation, :resolved]` Scrypath bridge and making enabled/misconfigured states
  observable.

### Doctor, Readiness, and Operational Truth

- **D-13:** `/health` remains shallow liveness: a mounted plug that says the app can answer HTTP. Do
  not turn it into an expensive or misleading readiness check.
- **D-14:** `mix cairnloop.doctor` is the primary readiness/trust diagnostic surface for this phase.
  Extend it with reason-forward checks for repo config, mounted operations/dashboard surfaces,
  widget verifier posture, email webhook auth config, MCP auth/token posture, notifier config,
  Oban availability, retrieval/pgvector where practical, and Scrypath enabled/misconfigured states.
- **D-15:** If a runtime readiness endpoint is added, make it optional and honest under
  `cairnloop_operations/1`; do not replace `/health` semantics and do not claim checks that are not
  actually performed.

### Claude's Discretion

- No owner-level question was escalated. The repo instruction says GSD discuss-phase should
  auto-decide routine trust-sensitive implementation calls and surface only genuinely expensive or
  irreversible choices. Phase 58 has no such unresolved choice after the Phase 57 audit: the roadmap
  and requirements already lock the fail-closed direction.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning and Requirements

- `.planning/PROJECT.md` - current project state, vM019 focus, and architectural invariants.
- `.planning/REQUIREMENTS.md` - TRUST-01 through TRUST-05 and OPS-01 through OPS-04 are Phase 58 scope.
- `.planning/ROADMAP.md` - Phase 58 goal and success criteria.
- `.planning/STATE.md` - carried vM019 decisions, pending todos, and dirty-worktree warning.
- `.planning/phases/57-evidence-and-trust-audit/57-CONTEXT.md` - audit baseline handoff and deferred
  runtime trust-boundary fixes.
- `CLAUDE.md` - decision policy, sealed-contract posture, test expectations, and operator-copy rules.

### Audit Evidence and Docs

- `docs/software-quality-evaluation.md` - primary evidence for widget identity, email, MCP, Scrypath,
  telemetry/logging, and readiness gaps.
- `docs/postgres-schema-prefix.md` - Phase 59 is the prefix implementation phase, but its doctor/
  readiness notes matter when adding operational checks in Phase 58.
- `guides/07-auth-and-operator-identity.md` - establishes `host_user_id` as operator identity and
  documents the static-session trap.
- `guides/04-troubleshooting.md` - should be updated if doctor/readiness or side-effect diagnostics
  gain new output.
- `guides/05-mcp-clients.md` - should be aligned with the actual MCP auth module, token format, and
  fail-closed behavior.

### Trust and Ingress Code

- `lib/cairnloop/channels/widget_socket.ex` - currently accepts any binary `"token"` into
  `socket.assigns[:user_token]`.
- `lib/cairnloop/channels/widget_channel.ex` - currently creates conversations using the widget
  token as `host_user_id`.
- `lib/cairnloop/chat.ex` - conversation creation, resolution, telemetry, and side-effect event source.
- `lib/cairnloop/conversation.ex` - current persistence shape and `host_user_id` field.
- `lib/cairnloop/ingress/email_webhook_plug.ex` - email webhook token auth seam.
- `lib/cairnloop/workers/process_message.ex` - email stub and widget message worker.
- `lib/cairnloop/web/mcp/auth_plug.ex` - non-halting Bearer-token assignment currently used by MCP.
- `lib/cairnloop/web/mcp/router.ex` - JSON-RPC handlers for `initialize`, `tools/list`, and
  `tools/call`.
- `lib/cairnloop/application.ex` - Scrypath telemetry handler attachment and conversation-resolved
  bridge.
- `lib/cairnloop/workers/ingest_scrypath.ex` - Scrypath request defaults and worker behavior.
- `lib/cairnloop/telemetry.ex`, `lib/cairnloop/retrieval/telemetry.ex`,
  `lib/cairnloop/governance/telemetry.ex` - existing telemetry vocabulary and bounded-metadata
  patterns.
- `lib/cairnloop/doctor.ex`, `lib/mix/tasks/cairnloop.doctor.ex`,
  `lib/cairnloop/web/health_plug.ex`, `lib/cairnloop/router.ex` - doctor, health, operations, and
  host-router integration points.

### Existing Regression Tests

- `test/cairnloop/channels/widget_channel_test.exs` - current widget join expectations.
- `test/cairnloop/ingress/email_webhook_plug_test.exs` - existing no-default-secret email tests.
- `test/cairnloop/web/mcp/router_test.exs` - MCP route behavior; add missing-token coverage for
  read/metadata methods.
- `test/cairnloop/application_test.exs` - Scrypath default-disabled behavior.
- `test/cairnloop/doctor_test.exs` - DB-free doctor engine tests to extend with new diagnostics.
- `test/cairnloop/workers/process_message_test.exs` - message worker logging behavior.
- `test/cairnloop/retrieval/telemetry_test.exs`,
  `test/cairnloop/governance/telemetry_test.exs`,
  `test/cairnloop/outbound/telemetry/traces_test.exs` - patterns for bounded telemetry assertions.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Cairnloop.Doctor.checks/2` already accepts injected config opts and fabricated routers, making new
  DB-free trust diagnostics straightforward to test.
- `Cairnloop.Web.MCP.AuthPlug` already validates Bearer tokens and assigns `:mcp_token`; planning can
  turn this into a fail-closed guard without inventing a parallel token system.
- Retrieval, governance, and outbound telemetry modules already normalize metadata to allow-lists.
  Reuse that pattern for conversation lifecycle metadata instead of one-off filtering.
- Existing email and Scrypath tests show recent hardening has begun; extend those tests rather than
  replacing the seams.

### Established Patterns

- Host-owned auth stays host-owned. Cairnloop supplies seams and safe defaults, not a dashboard or
  widget auth system.
- Web/operator reads should continue through narrow facades where applicable; do not introduce direct
  web-layer schema queries as part of trust fixes.
- Public function signatures from prior shipped milestones are sealed. Prefer additive options,
  behaviours, helper modules, or narrow new functions over changing established call shapes.
- `/health` is intentionally liveness only. Use doctor/strict checks or an optional readiness surface
  for deeper operational truth.

### Integration Points

- Widget auth connects at `WidgetSocket.connect/3` and `WidgetChannel.join/3`.
- Email auth connects at `EmailWebhookPlug.call/2` before body parse and Oban enqueue.
- MCP auth connects inside `Cairnloop.Web.MCP.Router.call/2` and method dispatch.
- Scrypath side effects connect through `Cairnloop.Application.attach_optional_telemetry/0`,
  `handle_conversation_resolved/4`, and `IngestScrypath.perform/1`.
- Doctor/readiness connects through `Cairnloop.Doctor.checks/2`, the `mix cairnloop.doctor` task, and
  `Cairnloop.Router.cairnloop_operations/1`.

</code_context>

<specifics>
## Specific Ideas

- Add regression tests for unauthenticated MCP `initialize` / `tools/list`, missing widget verifier in
  production posture, invalid email webhook token, Scrypath disabled by default, Scrypath enabled with
  dummy config, and raw support content exclusion from logs/telemetry.
- Keep the email webhook product scope intentionally small. Authentication hardening belongs here;
  rich provider-specific email ingestion belongs in a future adopter-pulled phase.
- When source and Phase 57 audit disagree, trust live source but preserve the audit's intent. Example:
  Scrypath is already default-disabled in `Application`; Phase 58 should make that contract explicit,
  validated, documented, and covered for misconfigured enabled state.

</specifics>

<deferred>
## Deferred Ideas

- Full provider-specific email-to-conversation workflows remain a future host-integration/product
  phase.
- Phase 59 owns dedicated Postgres schema/default-prefix implementation. Phase 58 may add additive
  identity fields if required, but should not solve prefix migration.
- Phase 60 owns broad README/ExDoc/SECURITY/UPGRADING/package docs truth. Phase 58 should update only
  docs directly needed for auth, doctor, side effects, and troubleshooting truth.
- Phase 61 owns CI/CD efficiency and release confidence changes.

</deferred>

---

*Phase: 58-Identity, Ingress, and Side-Effect Trust*
*Context gathered: 2026-06-29*
