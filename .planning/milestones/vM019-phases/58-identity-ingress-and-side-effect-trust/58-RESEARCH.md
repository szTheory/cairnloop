# Phase 58: Identity, Ingress, and Side-Effect Trust - Research

**Researched:** 2026-06-29
**Domain:** Elixir/Phoenix trust-boundary hardening for identity, ingress auth, telemetry/log privacy, optional Oban side effects, and operational diagnostics
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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

### the agent's Discretion
### Claude's Discretion

- No owner-level question was escalated. The repo instruction says GSD discuss-phase should
  auto-decide routine trust-sensitive implementation calls and surface only genuinely expensive or
  irreversible choices. Phase 58 has no such unresolved choice after the Phase 57 audit: the roadmap
  and requirements already lock the fail-closed direction.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

- Full provider-specific email-to-conversation workflows remain a future host-integration/product
  phase.
- Phase 59 owns dedicated Postgres schema/default-prefix implementation. Phase 58 may add additive
  identity fields if required, but should not solve prefix migration.
- Phase 60 owns broad README/ExDoc/SECURITY/UPGRADING/package docs truth. Phase 58 should update only
  docs directly needed for auth, doctor, side effects, and troubleshooting truth.
- Phase 61 owns CI/CD efficiency and release confidence changes.
</user_constraints>

## Summary

Phase 58 should be planned as a focused trust-boundary hardening phase, not as a product expansion phase. The central codebase finding is that widget customer tokens currently flow into `Conversation.host_user_id` and the operator conversation LiveView later uses that same field as the actor for recovery, resolve, governed proposals, approvals, search scope, context lookup, and quick-fix scope. [VERIFIED: codebase grep: lib/cairnloop/channels/widget_socket.ex:8-17, lib/cairnloop/channels/widget_channel.ex:12-18, lib/cairnloop/chat.ex:66-72, lib/cairnloop/web/conversation_live.ex:247-298,320-366,428-470]

Plan the identity work as a two-part fix: add an explicit widget customer-token verifier seam at socket connect time, then make dashboard/operator actions use the LiveView session `host_user_id` rather than `Conversation.host_user_id`. [VERIFIED: codebase grep: lib/cairnloop/router.ex:78-92, lib/cairnloop/web/inbox_live.ex:82-110] Use an additive conversation field for customer/session identity; the recommended field name is `customer_ref` because it is opaque, host-owned, and avoids implying durable PII ownership. [ASSUMED]

Ingress and side-effect work has existing seams to harden rather than replace: `EmailWebhookPlug` already has no literal default token but should halt after auth failures, MCP already validates Bearer tokens but does not require them for `initialize` or `tools/list`, Scrypath is default-disabled but the enabled path accepts dummy defaults and relies on generic telemetry metadata for support text, and Doctor already has a DB-free engine that can be extended with trust diagnostics. [VERIFIED: codebase grep: lib/cairnloop/ingress/email_webhook_plug.ex:8-48, lib/cairnloop/web/mcp/auth_plug.ex:1-28, lib/cairnloop/web/mcp/router.ex:46-177, lib/cairnloop/application.ex:27-64, lib/cairnloop/workers/ingest_scrypath.ex:5-29, lib/cairnloop/doctor.ex:40-59]

**Primary recommendation:** Implement Phase 58 in five slices: identity separation, ingress fail-closed behavior, bounded conversation telemetry, Scrypath opt-in validation, and doctor/docs/test truth. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Widget customer-token verification | Browser ingress socket | API / Backend | `WidgetSocket.connect/3` is where Phoenix Socket params are authenticated and assigned before channel joins. [CITED: https://phoenix.hexdocs.pm/Phoenix.Socket.html] |
| Customer identity persistence | Database / Storage | API / Backend | Conversation schema currently has only `host_user_id`; separating customer identity requires schema, changeset, installer, example, and test-host migration coordination. [VERIFIED: codebase grep: lib/cairnloop/conversation.ex:6-25, lib/mix/tasks/cairnloop/install.ex:58-66, priv/test_host/migrations/20260101000000_create_host_owned_tables.exs:12-20] |
| Operator attribution | Frontend Server (LiveView) | API / Backend | Dashboard session data is passed through `cairnloop_dashboard/2`, and `ConversationLive` must thread the session actor to Chat/Governance/Outbound. [VERIFIED: codebase grep: lib/cairnloop/router.ex:78-117, lib/cairnloop/web/conversation_live.ex:17-32,247-366] |
| Email webhook auth | API / Backend | External provider | The plug owns request authentication before body parsing and Oban enqueue; provider-specific email product behavior is out of scope. [VERIFIED: codebase grep: lib/cairnloop/ingress/email_webhook_plug.ex:8-48] |
| MCP auth | API / Backend | Database / Storage | Router method dispatch owns fail-closed behavior; token validation uses hashed `cairnloop_mcp_tokens` records. [VERIFIED: codebase grep: lib/cairnloop/web/mcp/router.ex:46-177, lib/cairnloop/mcp.ex:15-49, lib/cairnloop/mcp/token.ex:14-31] |
| Bounded telemetry and logs | API / Backend | Observability exporters | Telemetry is emitted from domain modules and should remain observability-only, with metadata allow-lists like retrieval/governance/outbound. [VERIFIED: CLAUDE.md; codebase grep: lib/cairnloop/retrieval/telemetry.ex:5-7,139-157, lib/cairnloop/governance/telemetry.ex:3-8,61-80, lib/cairnloop/telemetry.ex:89-94] |
| Optional Scrypath side effects | API / Backend | External service | `Application` attaches the resolved-conversation telemetry bridge and `IngestScrypath` performs outbound HTTP with Req. [VERIFIED: codebase grep: lib/cairnloop/application.ex:27-64, lib/cairnloop/workers/ingest_scrypath.ex:5-29] |
| Doctor/readiness truth | CLI / API Backend | CDN / Static health | `/health` is a liveness plug; Doctor is the richer config and readiness diagnostic engine. [VERIFIED: codebase grep: lib/cairnloop/web/health_plug.ex:1-19, lib/cairnloop/doctor.ex:1-59, lib/mix/tasks/cairnloop.doctor.ex:34-60] |

## Project Constraints (from AGENTS.md)

- Read `CLAUDE.md` before working in this repo. [VERIFIED: AGENTS.md]
- For UI work, read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`. [VERIFIED: AGENTS.md]
- The shipped dashboard uses Cairnloop tokenized `.cl-*` and BEM CSS, not Tailwind. [VERIFIED: AGENTS.md; docs/operator-ui-principles.md]
- Adopter-facing UI changes should stay inside the component system so spacing, motion, color, and accessibility improve globally. [VERIFIED: AGENTS.md; docs/operator-ui-principles.md]
- The owner wants researched decisions made rather than broad choice prompts. [VERIFIED: CLAUDE.md]
- Warnings-clean builds are mandatory, with `mix compile --warnings-as-errors` and `mix ci.fast` before declaring headless work done. [VERIFIED: CLAUDE.md; mix.exs:88-112]
- `Cairnloop.Repo` may be unavailable in this workspace; prefer headless/pure tests and mark DB-required tests with `# REPO-UNAVAILABLE` when they cannot run here. [VERIFIED: CLAUDE.md; test/test_helper.exs:1-23]
- Durable Ecto records and events are workflow truth; telemetry is observability only. [VERIFIED: CLAUDE.md; guides/03-host-integration.md:313-318]
- New web reads should go through narrow facades where applicable, especially `Cairnloop.Governance`, not direct schema queries from the web layer. [VERIFIED: CLAUDE.md; lib/cairnloop/web/conversation_live.ex:408-413]
- Snapshot trust facts at decision time, seal completed public contracts where feasible, and use calm fail-closed operator copy. [VERIFIED: CLAUDE.md]
- No project-local `.claude/skills` or `.agents/skills` `SKILL.md` files were found. [VERIFIED: local command]
- No `.planning/graphs/graph.json` file was present, so no graph context was available for this research. [VERIFIED: local command]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUST-01 | Customer/browser identity and operator identity are not conflated in runtime flows, persisted data, recovery actions, approvals, search, or audit context. | Fix `WidgetSocket`, `WidgetChannel`, `Chat.create_customer_conversation/1`, `Conversation` schema/migrations, and `ConversationLive` actor/search/context paths. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep] |
| TRUST-02 | Widget ingress has an explicit host-verification seam for customer/session tokens and fails closed when verification is not configured for production. | Add configured verifier to `WidgetSocket.connect/3`; require explicit demo/test verifier; never accept arbitrary binary tokens by default. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/channels/widget_socket.ex:8-17] |
| TRUST-03 | Email webhook ingress does not ship with a literal default secret and documents the host's authentication responsibility clearly. | Existing code already has no literal default token; add halt semantics, success-path tests, and docs that auth is host-configured. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/ingress/email_webhook_plug.ex:38-47, test/cairnloop/ingress/email_webhook_plug_test.exs:19-41] |
| TRUST-04 | MCP auth behavior matches docs and fails closed for token-required methods before exposing tool metadata or write surfaces. | Protect `initialize`, `tools/list`, and `tools/call`; align docs with `AuthPlug` and raw token format. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/web/mcp/router.ex:64-83,85-177, guides/05-mcp-clients.md:11-37] |
| TRUST-05 | Logs and telemetry metadata exclude customer message bodies, secrets, raw payloads, and other high-risk support content unless explicitly opted into a diagnostic mode. | Bound `Chat.resolve_conversation/2` metadata like retrieval/governance/outbound, and add negative tests for raw keys. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/chat.ex:280-338, lib/cairnloop/retrieval/telemetry.ex:139-157, test/cairnloop/retrieval/telemetry_test.exs:77-102] |
| OPS-01 | Optional Scrypath/external automation side effects are inert by default and require an explicit host opt-in. | Preserve default-disabled `:scrypath_automation_enabled` behavior and make the opt-in contract documented and tested. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/application.ex:27-64, test/cairnloop/application_test.exs:14-36] |
| OPS-02 | When optional side effects are enabled, config errors are caught early enough for a host developer to fix them without production guesswork. | Reject enabled Scrypath with missing/placeholder URL/key before enqueue and surface the state in doctor/strict. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/workers/ingest_scrypath.ex:5-20] |
| OPS-03 | `/health` remains honest liveness, while readiness/doctor output documents DB, Oban, pgvector, notifier, and optional automation status without claiming more than it checks. | Keep `HealthPlug` shallow and extend `Doctor.checks/2` with reason-forward checks. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: lib/cairnloop/web/health_plug.ex:1-19, lib/cairnloop/doctor.ex:40-59] |
| OPS-04 | Production debugging has enough hooks to identify whether Cairnloop, host config, DB state, Oban, or an external dependency is failing. | Update doctor output, troubleshooting docs, and telemetry docs for clear failure domains. [VERIFIED: .planning/REQUIREMENTS.md; codebase grep: guides/04-troubleshooting.md:66-82, guides/03-host-integration.md:313-376] |
</phase_requirements>

## Standard Stack

Use the existing locked project stack; do not add packages for this phase. [VERIFIED: mix.exs; mix.lock; local command]

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 on Erlang/OTP 28 | Runtime, compiler, ExUnit, Mix tasks | Project declares `elixir: "~> 1.19"` and local runtime matches. [VERIFIED: local command; mix.exs:6-7] |
| Phoenix | 1.8.7 locked; Hex latest checked 1.8.8 on 2026-06-10 | Router, Socket, Plug integration | Existing project dependency; Phase 58 needs auth seams, not a framework upgrade. [VERIFIED: mix.lock; mix hex.info phoenix] |
| Phoenix LiveView | 1.1.30 locked; Hex latest checked 1.2.4 on 2026-06-29 | Operator dashboard session and event handling | Existing dashboard stack; LiveView docs support session/on_mount ownership. [VERIFIED: mix.lock; mix hex.info phoenix_live_view; CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] |
| Ecto SQL | 3.13.5 locked; Hex latest checked 3.14.0 on 2026-05-19 | Schemas, changesets, migrations, transactions | Existing persistence layer for conversations, MCP tokens, jobs, and audit records. [VERIFIED: mix.lock; mix hex.info ecto_sql] |
| Oban | 2.22.1 locked; Hex latest checked 2.23.0 on 2026-05-27 | Durable background jobs and test helpers | Existing queue layer for widget/email/Scrypath jobs; Oban.Testing supports focused queue assertions. [VERIFIED: mix.lock; mix hex.info oban; CITED: https://hexdocs.pm/oban/Oban.Testing.html] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Plug | 1.19.2 locked; Hex latest checked 1.20.1 on 2026-06-23 | Email webhook and MCP router request handling | Use `halt/1` after `send_resp/3` for fail-closed auth plugs. [VERIFIED: mix.lock; mix hex.info plug; CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Jason | 1.4.5 locked; Hex latest checked 1.4.5 on 2026-05-05 | JSON webhook and JSON-RPC parse/encode | Keep existing parser and string-key JSON-RPC dispatch. [VERIFIED: mix.lock; mix hex.info jason] |
| telemetry | 1.4.2 locked; Hex latest checked 1.4.2 on 2026-05-11 | Span and point-event observability | Keep bounded metadata; stop metadata is independent of start metadata and must be explicit. [VERIFIED: mix.lock; mix hex.info telemetry; CITED: https://telemetry.hexdocs.pm/telemetry.html] |
| Req | 0.5.17 locked; Hex latest checked 0.6.2 on 2026-06-19 | Scrypath HTTP client | Use existing Req.Test pattern for worker tests; no new HTTP client. [VERIFIED: mix.lock; mix hex.info req; test/cairnloop/workers/ingest_scrypath_test.exs:8-25] |
| NimbleOptions | 1.1.1 locked; Hex latest checked 1.1.1 on 2024-05-25 | Router option validation and docs | Use existing router/installer option validation style for any new operations/readiness options. [VERIFIED: mix.lock; mix hex.info nimble_options; lib/cairnloop/router.ex:10-32] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing Phoenix session/on_mount auth seam | Cairnloop-owned auth/session system | Rejected by project scope and host-owned auth invariant. [VERIFIED: CLAUDE.md; guides/07-auth-and-operator-identity.md:3-7] |
| Existing Plug/Jason MCP router | New JSON-RPC/MCP server package | Rejected because current router already covers method dispatch and needs fail-closed guards, not a rewrite. [VERIFIED: codebase grep: lib/cairnloop/web/mcp/router.ex:46-177] |
| Existing telemetry allow-list modules | Open-ended Logger/metadata scrubber package | Rejected because retrieval/governance/outbound already establish local bounded-metadata patterns. [VERIFIED: codebase grep: lib/cairnloop/retrieval/telemetry.ex:139-157, lib/cairnloop/governance/telemetry.ex:65-80] |
| Existing Oban/Req Scrypath worker | New side-effect orchestration framework | Rejected because Phase 58 is limited to the existing resolved-conversation Scrypath bridge. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md] |

**Installation:**

```bash
# No new external packages for Phase 58.
mix deps.get --check-locked
```

**Version verification:** Existing versions were verified from `mix.lock`, local `mix --version`/`elixir --version`, and `mix hex.info` for Phoenix, LiveView, Oban, Plug, Ecto SQL, Jason, Req, NimbleOptions, and telemetry. [VERIFIED: local command]

## Package Legitimacy Audit

No new external packages are recommended for this phase, so the Package Legitimacy Gate does not apply. [VERIFIED: mix.exs; .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None | - | - | - | - | N/A | No package install planned. [VERIFIED: research decision] |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```text
Widget browser
  -> WidgetSocket.connect(params)
  -> configured widget verifier
  -> socket.assigns.customer_ref
  -> WidgetChannel.join("widget:lobby")
  -> Chat.create_customer_conversation(customer_ref: ...)
  -> Conversation row: customer_ref set, host_user_id nil unless operator/session later supplies it

Operator dashboard request
  -> host router pipeline/on_mount
  -> cairnloop_dashboard session MFA
  -> ConversationLive.assigns.host_user_id
  -> Chat / Governance / Outbound actions with session actor
  -> durable DB/audit rows

Email provider
  -> EmailWebhookPlug auth verifier/token
  -> parse minimal body
  -> ProcessMessage Oban job
  -> existing email stub

MCP client
  -> public well-known metadata only
  -> MCP Router AuthPlug
  -> require token for initialize/tools/list/tools/call
  -> Governance.propose for writes

Conversation resolved
  -> bounded conversation telemetry
  -> optional Scrypath bridge checks enabled + valid config
  -> IngestScrypath worker fetches durable data, then Req.post

Host/operator
  -> mix cairnloop.doctor --strict
  -> repo/router/dashboard/health/widget/email/MCP/notifier/Oban/retrieval/Scrypath findings
```

### Recommended Project Structure

Keep edits in existing modules and add only narrow helper modules when they remove repeated config checks. [VERIFIED: codebase grep]

```text
lib/cairnloop/
├── channels/                # widget socket/channel verifier use
├── ingress/                 # email webhook auth seam
├── web/mcp/                 # MCP auth and JSON-RPC method guards
├── web/                     # dashboard LiveViews that thread operator actor
├── workers/                 # Scrypath and message job behavior
├── doctor.ex                # DB-free trust diagnostics
├── telemetry.ex             # public telemetry docs
├── chat.ex                  # conversation creation, resolve, bounded lifecycle telemetry
└── conversation.ex          # additive customer identity field
```

### Component Responsibilities

| File | Responsibility | Planner Notes |
|------|----------------|---------------|
| `lib/cairnloop/channels/widget_socket.ex` | Authenticate browser/customer token before assigning socket identity. [VERIFIED: codebase grep: lines 8-17] | Replace implicit binary acceptance with configured verifier. |
| `lib/cairnloop/channels/widget_channel.ex` | Create customer conversation from verified customer identity. [VERIFIED: codebase grep: lines 12-18] | Stop sending widget token as `host_user_id`. |
| `lib/cairnloop/chat.ex` | Insert conversations, resolve conversations, emit telemetry. [VERIFIED: codebase grep: lines 66-72,280-338] | Add customer identity attrs and bounded resolve metadata. |
| `lib/cairnloop/conversation.ex` | Persistence shape for conversation identity. [VERIFIED: codebase grep: lines 6-25] | Add `customer_ref` to schema and changeset if accepted by planner. |
| `lib/mix/tasks/cairnloop/install.ex` | Generated host base migration. [VERIFIED: codebase grep: lines 58-66] | Include additive customer identity column for new installs. |
| `priv/test_host/migrations/...create_host_owned_tables.exs` | Test-host conversations table. [VERIFIED: codebase grep: lines 12-20] | Mirror additive schema for tests. |
| `examples/cairnloop_example/priv/repo/migrations/...create_cairnloop_tables.exs` | Example app base conversations table. [VERIFIED: codebase grep: lines 5-13] | Mirror additive schema for demo truth. |
| `lib/cairnloop/web/conversation_live.ex` | Operator conversation actions. [VERIFIED: codebase grep: lines 17-32,247-366,428-470] | Assign `host_user_id` from session and fail closed when missing. |
| `lib/cairnloop/ingress/email_webhook_plug.ex` | Email webhook auth/parse/enqueue. [VERIFIED: codebase grep: lines 8-48] | Add `halt/1` after responses and keep provider scope narrow. |
| `lib/cairnloop/web/mcp/router.ex` | MCP JSON-RPC auth and method dispatch. [VERIFIED: codebase grep: lines 46-177] | Require token before exposing `initialize` and `tools/list` metadata. |
| `lib/cairnloop/application.ex` | Optional Scrypath telemetry bridge. [VERIFIED: codebase grep: lines 27-64] | Validate opt-in config before enqueue. |
| `lib/cairnloop/workers/ingest_scrypath.ex` | Scrypath HTTP indexing worker. [VERIFIED: codebase grep: lines 5-29] | Remove dummy defaults as usable enabled config; fetch durable content inside worker. |
| `lib/cairnloop/doctor.ex` | DB-free diagnostic engine. [VERIFIED: codebase grep: lines 40-59] | Add trust checks with injected opts for pure tests. |

### Pattern 1: Separate Customer Verifier From Operator Session

**What:** Browser/widget tokens authenticate customer/session identity at socket connect time; operator identity comes only from dashboard live session. [VERIFIED: codebase grep; CITED: https://phoenix.hexdocs.pm/Phoenix.Socket.html]

**When to use:** Use this for widget channel joins, customer labels, and any customer context that is not governance-bearing. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]

**Example:**

```elixir
# Source: Phoenix.Socket docs + current WidgetSocket shape.
def connect(%{"token" => token}, socket, _connect_info) when is_binary(token) do
  with {:ok, customer} <- widget_verifier().verify_widget_token(token) do
    {:ok, assign(socket, :customer_ref, customer.ref)}
  else
    _ -> {:error, :unauthorized}
  end
end
```

### Pattern 2: LiveView Session Actor Is Required For Governed Actions

**What:** `ConversationLive` should assign `host_user_id` from session in `mount/3` and use that assign for recovery, resolve, Governance approve/reject/defer/propose, and search scope. [VERIFIED: codebase grep: lib/cairnloop/web/conversation_live.ex:17-32,247-366,466-470]

**When to use:** Use for every operator/governance action on dashboard surfaces. [VERIFIED: guides/07-auth-and-operator-identity.md:15-40]

**Example:**

```elixir
# Source: current InboxLive session pattern.
def mount(%{"id" => id}, session, socket) do
  socket =
    socket
    |> assign(:host_user_id, Map.get(session, "host_user_id"))
    |> reload_conversation_with_context(id)

  {:ok, socket}
end
```

### Pattern 3: Halt Fail-Closed Plugs After Responses

**What:** When a Plug sends an auth failure response, call `halt/1` so downstream plugs cannot continue. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]

**When to use:** Use for email webhook auth failures and MCP unauthorized responses. [VERIFIED: codebase grep: lib/cairnloop/ingress/email_webhook_plug.ex:26-35, lib/cairnloop/web/mcp/router.ex:171-177]

**Example:**

```elixir
# Source: Plug.Conn halt/send_resp docs.
conn
|> put_resp_content_type("application/json")
|> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
|> halt()
```

### Pattern 4: Bounded Telemetry Metadata Allow-Lists

**What:** Convert arbitrary inputs into low-cardinality, allow-listed telemetry metadata before emitting. [VERIFIED: codebase grep: lib/cairnloop/retrieval/telemetry.ex:139-157, lib/cairnloop/governance/telemetry.ex:65-80]

**When to use:** Use for `[:cairnloop, :conversation, :resolve, :stop]` and `[:cairnloop, :conversation, :resolved]`. [VERIFIED: codebase grep: lib/cairnloop/chat.ex:287-338]

**Example:**

```elixir
# Source: retrieval/governance telemetry allow-list pattern.
defp conversation_resolved_metadata(_conversation, result) do
  %{
    outcome: if(match?({:ok, _}, result), do: :resolved, else: :failed),
    side_effects: :not_applicable
  }
end
```

### Pattern 5: Doctor Checks Stay Pure-Ish And Injectable

**What:** Add trust diagnostics as functions driven by `opts` or `Application.get_env/3`, so tests can inject states without booting a live app. [VERIFIED: codebase grep: lib/cairnloop/doctor.ex:33-59,163-165]

**When to use:** Use for widget verifier posture, email token/verifier, MCP auth/token posture, Oban availability, retrieval/pgvector practical checks, notifier config, and Scrypath enabled/misconfigured state. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]

### Anti-Patterns to Avoid

- **Persisting widget token as `host_user_id`:** This is the current identity conflation and must be removed. [VERIFIED: codebase grep: lib/cairnloop/channels/widget_channel.ex:10-18]
- **Using `conversation.host_user_id || "operator"` as an actor:** This invents attribution and breaks fail-closed identity. [VERIFIED: codebase grep: lib/cairnloop/web/conversation_live.ex:269-273]
- **Exposing MCP `tools/list` without auth:** Tool metadata is model-controlled context and should not be exposed before token validation. [VERIFIED: codebase grep: lib/cairnloop/web/mcp/router.ex:77-83; CITED: https://modelcontextprotocol.io/specification/2025-11-25/server/tools]
- **Using raw telemetry metadata as side-effect payload:** Generic telemetry metadata is not a support-content transport. [VERIFIED: CLAUDE.md; codebase grep: lib/cairnloop/application.ex:47-53]
- **Turning `/health` into readiness:** `/health` is already a shallow liveness plug; use Doctor or optional readiness for richer checks. [VERIFIED: codebase grep: lib/cairnloop/web/health_plug.ex:1-19; .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Host/operator auth | Cairnloop-owned login/session framework | Host router pipelines, LiveView `on_mount`, and `session` MFA | Cairnloop is embedded and host-owned; docs already define this seam. [VERIFIED: CLAUDE.md; guides/07-auth-and-operator-identity.md:44-56; CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] |
| Widget token verification product | Provider-specific auth product | Small configured verifier behaviour/function | Phase scope is auth seam and fail-closed default, not customer identity product work. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md] |
| Email provider integration | Full email-to-conversation pipeline | Existing `EmailWebhookPlug` plus minimal verifier/token seam | Rich email workflows are explicitly deferred. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md] |
| MCP server rewrite | New MCP framework or bespoke OAuth server | Existing `MCP.Router`, `AuthPlug`, hashed token table, and public well-known metadata where needed | Current code already validates Bearer tokens and routes writes through Governance. [VERIFIED: codebase grep: lib/cairnloop/web/mcp/router.ex:85-132, lib/cairnloop/mcp.ex:15-49] |
| Scrypath orchestration | New external automation bus | Existing default-disabled telemetry bridge, Oban worker, Req client | Phase only gates the resolved-conversation Scrypath bridge. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md] |
| Log/telemetry scrubber framework | Regex-based global scrubber | Explicit metadata allow-lists at emission sites | Existing retrieval/governance/outbound code already uses allow-list normalization. [VERIFIED: codebase grep: lib/cairnloop/retrieval/telemetry.ex:139-157, lib/cairnloop/governance/telemetry.ex:65-80] |

**Key insight:** This phase is safer when each boundary fails closed at the point where data enters or leaves Cairnloop; global cleanup after the fact is too late for identity, audit, telemetry, and side effects. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md; CLAUDE.md]

## Common Pitfalls

### Pitfall 1: Fixing Widget Auth But Leaving Operator Actions On Conversation Identity

**What goes wrong:** A verifier is added, but `ConversationLive` still uses `conversation.host_user_id` for recovery, resolve, approvals, search, and context. [VERIFIED: codebase grep: lib/cairnloop/web/conversation_live.ex:247-366,428-470]
**Why it happens:** The current widget path stores the customer token in the same field the dashboard later treats as operator identity. [VERIFIED: codebase grep: lib/cairnloop/channels/widget_channel.ex:10-18]
**How to avoid:** Plan identity separation and dashboard actor threading in the same wave. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]
**Warning signs:** Tests still assert `host_user_id="demo_customer"` for widget-created conversations. [VERIFIED: codebase grep: test/integration/widget_channel_test.exs:94-99]

### Pitfall 2: Updating Schema Without Installer And Example Parity

**What goes wrong:** Runtime schema expects a new identity field, but generated host migrations, test-host migrations, or the example app do not create it. [VERIFIED: codebase grep: lib/cairnloop/conversation.ex:6-25, lib/mix/tasks/cairnloop/install.ex:58-66, examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs:5-13]
**Why it happens:** Cairnloop is host-owned, so base support tables live in host migrations, not only library migrations. [VERIFIED: codebase grep: priv/test_host/migrations/20260101000000_create_host_owned_tables.exs:1-8]
**How to avoid:** Include schema, generated installer migration, example migration, test-host migration, and additive upgrade migration in one slice. [VERIFIED: codebase grep]
**Warning signs:** DB-free tests pass but integration/example migrations fail or omit customer identity. [VERIFIED: test/test_helper.exs:1-23]

### Pitfall 3: Sending A Plug Response Without Halting

**What goes wrong:** An unauthorized or bad request response is sent but downstream pipeline code can still run. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
**Why it happens:** `send_resp/3` sends a response; it is not a replacement for `halt/1`. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
**How to avoid:** Pipe all auth-failure responses through `halt/1`. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
**Warning signs:** `EmailWebhookPlug` returns `send_resp` in error branches without `halt`. [VERIFIED: codebase grep: lib/cairnloop/ingress/email_webhook_plug.ex:26-35]

### Pitfall 4: Treating `/health` As Readiness

**What goes wrong:** Operators infer DB, Oban, vector, notifier, or side-effect readiness from a liveness endpoint that only returns `{"status":"ok"}`. [VERIFIED: codebase grep: lib/cairnloop/web/health_plug.ex:1-19]
**Why it happens:** Current router docs call `/health` liveness/readiness even though the plug is shallow. [VERIFIED: codebase grep: guides/03-host-integration.md:264-270]
**How to avoid:** Keep `/health` shallow and move readiness/trust detail to `mix cairnloop.doctor` and optional honest readiness under `cairnloop_operations/1`. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]
**Warning signs:** Docs or tests claim `/health` verifies DB or background workers. [VERIFIED: codebase grep: guides/03-host-integration.md:264-270]

### Pitfall 5: Letting Conversation Telemetry Carry Durable Or Sensitive Facts

**What goes wrong:** Attached telemetry handlers can export full conversations, actor IDs, arbitrary metadata, or support content. [VERIFIED: codebase grep: lib/cairnloop/chat.ex:280-338]
**Why it happens:** `Chat.resolve_conversation/2` currently builds `meta` with `host_user_id`, `actor`, arbitrary `metadata`, and later adds `results.conversation`. [VERIFIED: codebase grep: lib/cairnloop/chat.ex:280-338]
**How to avoid:** Emit only bounded lifecycle metadata and keep support content in durable DB/audit rows or explicit diagnostic paths. [VERIFIED: CLAUDE.md; codebase grep: lib/cairnloop/retrieval/telemetry.ex:139-157]
**Warning signs:** Telemetry tests attach a handler and see keys such as `:conversation`, `:metadata`, `:host_user_id`, `:actor`, `:text`, `:content`, `:payload`, or `:raw_body`. [VERIFIED: codebase grep: test/cairnloop/retrieval/telemetry_test.exs:77-102, test/cairnloop/governance/telemetry_test.exs:105-165]

### Pitfall 6: Enabling Scrypath With Dummy Defaults

**What goes wrong:** A host opts in, but jobs enqueue against `https://api.scrypath.local/v1/index` with API key `"dummy"`. [VERIFIED: codebase grep: lib/cairnloop/workers/ingest_scrypath.ex:5-20]
**Why it happens:** The worker defaults are currently usable values unless a caller validates them before enqueue. [VERIFIED: codebase grep: lib/cairnloop/workers/ingest_scrypath.ex:5-20]
**How to avoid:** Centralize Scrypath config status as disabled, ready, or misconfigured; Doctor and the enqueue path should both use it. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]
**Warning signs:** `Application.handle_conversation_resolved/4` can call `enqueue_scrypath_ingest/1` when only `:scrypath_automation_enabled` is true. [VERIFIED: codebase grep: lib/cairnloop/application.ex:38-53]

### Pitfall 7: Breaking JSON-RPC Error Semantics While Adding Auth

**What goes wrong:** Planner changes every MCP error to HTTP 4xx and breaks existing JSON-RPC shape tests for malformed/unknown methods. [VERIFIED: codebase grep: test/cairnloop/web/mcp/router_test.exs:257-291]
**Why it happens:** Auth failure and JSON-RPC method errors are different concerns in the current code. [VERIFIED: codebase grep: lib/cairnloop/web/mcp/router.ex:153-177]
**How to avoid:** Keep unauthorized requests as HTTP 401 with `WWW-Authenticate`, but keep malformed/unsupported JSON-RPC errors as JSON-RPC envelopes unless the method was token-required and unauthenticated. [VERIFIED: codebase grep: lib/cairnloop/web/mcp/router.ex:158-177]
**Warning signs:** Unknown method tests fail after auth changes without a deliberate new contract. [VERIFIED: codebase grep: test/cairnloop/web/mcp/router_test.exs:261-291]

## Code Examples

Verified patterns from official sources and local code:

### Widget Verifier Config Shape

```elixir
# Source: Phoenix.Socket connect/3 docs and current WidgetSocket.
defp widget_verifier do
  Application.get_env(:cairnloop, :widget_token_verifier, Cairnloop.Widget.Verifier.FailClosed)
end
```

### Fail Closed Operator Actor Helper

```elixir
# Source: guides/07-auth-and-operator-identity.md and InboxLive mount pattern.
defp require_operator_actor(socket) do
  case socket.assigns[:host_user_id] do
    actor when is_binary(actor) and actor != "" -> {:ok, actor}
    _ -> {:error, put_flash(socket, :error, "Operator identity is not configured for this action.")}
  end
end
```

### Conversation Telemetry Negative Test Shape

```elixir
# Source: retrieval/governance telemetry tests.
refute Map.has_key?(metadata, :conversation)
refute Map.has_key?(metadata, :metadata)
refute Map.has_key?(metadata, :host_user_id)
refute Map.has_key?(metadata, :actor)
refute Map.has_key?(metadata, :content)
refute Map.has_key?(metadata, :raw_body)
```

### Scrypath Config Status Shape

```elixir
# Source: current Application/worker bridge; recommended narrow helper.
case Cairnloop.ScrypathConfig.status() do
  :disabled -> :ok
  {:ready, config} -> enqueue_scrypath_ingest(conversation_id, config)
  {:misconfigured, reasons} -> {:error, {:scrypath_misconfigured, reasons}}
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Accept any widget binary token and persist it as `host_user_id`. | Verify widget token through explicit host seam and persist customer/session identity separately. | Phase 58 plan target, 2026-06-29. [VERIFIED: context; ASSUMED recommendation] | Prevents customer/browser identity from becoming operator/audit identity. |
| Use conversation row `host_user_id` as operator actor in `ConversationLive`. | Use dashboard live-session `host_user_id` for operator actions and fail closed when absent. | Phase 58 plan target, 2026-06-29. [VERIFIED: context; codebase grep] | Makes recovery, resolve, approvals, search, and audit actor consistent with docs. |
| Let MCP `initialize` and `tools/list` expose capabilities/tool metadata without token. | Require Bearer token before token-required methods expose metadata or write surfaces. | Phase 58 plan target, 2026-06-29. [VERIFIED: context; codebase grep; CITED: https://modelcontextprotocol.io/specification/2025-11-25/server/tools] | Reduces unauthenticated tool discovery and aligns docs/code. |
| Emit raw/large conversation metadata into generic telemetry. | Emit bounded low-cardinality metadata and keep durable facts in DB/audit rows. | Established in retrieval/governance/outbound; apply to conversation lifecycle in Phase 58. [VERIFIED: codebase grep] | Avoids leaking support content into logs/APMs/metrics. |
| Enqueue Scrypath from telemetry metadata when enabled, with dummy URL/key worker defaults. | Enqueue only when explicitly enabled and config-valid; worker fetches durable content. | Phase 58 plan target, 2026-06-29. [VERIFIED: context; codebase grep] | Prevents unchosen external side effects and unsafe placeholder calls. |
| Describe `/health` as liveness/readiness. | Keep `/health` liveness and use Doctor/optional readiness for richer checks. | Phase 58 docs target, 2026-06-29. [VERIFIED: context; codebase grep] | Reduces misleading operational claims. |

**Deprecated/outdated:**

- `Cairnloop.Web.MCP.Auth` in `guides/05-mcp-clients.md` is stale because the code defines `Cairnloop.Web.MCP.AuthPlug`. [VERIFIED: codebase grep: guides/05-mcp-clients.md:11-18, lib/cairnloop/web/mcp/auth_plug.ex:1-6]
- Documentation that raw MCP tokens begin with `cl_mcp_...` is stale because `Cairnloop.MCP.issue_token/1` returns bare URL-safe Base64 and hashes it before storage. [VERIFIED: codebase grep: guides/05-mcp-clients.md:30-37, lib/cairnloop/mcp.ex:15-27]
- Operations docs that call `/health` readiness are stale because `HealthPlug` only returns static 200 JSON. [VERIFIED: codebase grep: guides/03-host-integration.md:264-270, lib/cairnloop/web/health_plug.ex:1-19]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The additive customer identity field should be named `customer_ref`. | Summary, Architecture Patterns, State of the Art | Low to medium: planner can choose a different additive field name, but every identity-separation task still applies. |

## Open Questions (RESOLVED)

1. **Exact additive field name**
   - What we know: A separate customer/session field is allowed and needed to stop overloading `host_user_id`. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md; codebase grep]
   - Resolution: Phase 58 uses `customer_ref` as the additive customer/session identity field everywhere: schema, installer migration output, test-host migration, example-app migration parity, widget channel attrs, and tests. This is opaque, host-owned, and avoids treating browser identity as an operator actor. [RESOLVED: revision iteration 1, 2026-06-29]

2. **Runtime readiness endpoint**
   - What we know: `/health` must remain liveness, and Doctor is primary readiness/trust output. [VERIFIED: .planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md]
   - Resolution: Phase 58 does not add a required runtime readiness endpoint. `/health` stays liveness-only per D-13. `mix cairnloop.doctor`, doctor CLI output, troubleshooting docs, and source-scan tests carry readiness/diagnostic truth per D-14. Any optional runtime readiness endpoint remains out of scope for these plans unless a later phase adds it under existing operations routing with honest, actually performed checks per D-15. [RESOLVED: revision iteration 1, 2026-06-29]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Compile/test/research | yes | 1.19.5 | None needed. [VERIFIED: local command] |
| Erlang/OTP | Compile/test/research | yes | 28 | None needed. [VERIFIED: local command] |
| Mix | Test and package lanes | yes | 1.19.5 | None needed. [VERIFIED: local command] |
| Node.js | GSD tooling/docs source scans if needed | yes | v22.14.0 | None needed. [VERIFIED: local command] |
| Git | Commit and diff hygiene | yes | 2.41.0 | None needed. [VERIFIED: local command] |
| Docker | Demo/e2e fallback lanes | yes | 29.5.2 | Not needed for DB-free Phase 58 tests. [VERIFIED: local command] |
| PostgreSQL server | Integration tests | yes | `pg_isready` accepted on `/tmp:5432`; psql 14.17 | Keep default `mix ci.fast` DB-free; run `mix ci.integration` only for DB-backed slices. [VERIFIED: local command; test/test_helper.exs] |
| Context7 MCP / `ctx7` | Library docs lookup | no | - | Used official docs via web search and stored digests. [VERIFIED: local command; CITED: official docs URLs in Sources] |

**Missing dependencies with no fallback:**
- None identified for planning or DB-free implementation. [VERIFIED: local command]

**Missing dependencies with fallback:**
- Context7/`ctx7`; fallback was official documentation via web search. [VERIFIED: local command; CITED: Sources]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit from Elixir 1.19.5, plus Phoenix.ChannelTest/LiveViewTest, Oban.Testing, and Plug.Test where already used. [VERIFIED: local command; codebase grep] |
| Config file | `mix.exs`, `test/test_helper.exs`, `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `mix ci.fast` [VERIFIED: mix.exs:88-112] |
| Full suite command | `mix ci` for full library gates; add `cd examples/cairnloop_example && mix test.e2e` if example/browser work changes. [VERIFIED: mix.exs:88-121; CLAUDE.md] |

### Phase Requirements To Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TRUST-01 | Widget customer identity is not persisted/reused as operator actor; ConversationLive uses session actor for resolve/recovery/Governance/search. | unit + integration | `mix test test/cairnloop/channels/widget_channel_test.exs test/cairnloop/web/conversation_live_test.exs --warnings-as-errors` | partial, update needed. [VERIFIED: codebase grep] |
| TRUST-02 | Missing widget verifier fails closed; explicit demo/test verifier succeeds. | unit | `mix test test/cairnloop/channels/widget_socket_test.exs --warnings-as-errors` | no, Wave 0 add. [VERIFIED: rg --files] |
| TRUST-03 | Email webhook requires configured token/verifier, rejects default/missing/wrong tokens, and halts after response. | unit | `mix test test/cairnloop/ingress/email_webhook_plug_test.exs --warnings-as-errors` | yes, expand. [VERIFIED: codebase grep] |
| TRUST-04 | MCP `initialize`, `tools/list`, and `tools/call` fail closed without Bearer token; malformed JSON still has expected JSON-RPC shape. | integration | `mix test test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` | yes, expand. [VERIFIED: codebase grep] |
| TRUST-05 | Conversation lifecycle telemetry excludes raw bodies, arbitrary metadata, IDs intended for durable records, and full structs. | unit | `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs --warnings-as-errors` | first file missing, Wave 0 add; second exists. [VERIFIED: rg --files; codebase grep] |
| OPS-01 | Scrypath bridge remains inert by default and explicit false. | unit | `mix test test/cairnloop/application_test.exs --warnings-as-errors` | yes, expand. [VERIFIED: codebase grep] |
| OPS-02 | Enabled Scrypath with missing/dummy URL/key does not enqueue and surfaces a clear config error. | unit | `mix test test/cairnloop/application_test.exs test/cairnloop/workers/ingest_scrypath_test.exs --warnings-as-errors` | yes, expand. [VERIFIED: codebase grep] |
| OPS-03 | `/health` stays shallow; Doctor reports repo/dashboard/ops/widget/email/MCP/notifier/Oban/retrieval/Scrypath without overclaiming. | unit | `mix test test/cairnloop/doctor_test.exs test/cairnloop/web/health_plug_test.exs --warnings-as-errors` | doctor exists; health test may need add. [VERIFIED: rg --files; codebase grep] |
| OPS-04 | Troubleshooting and telemetry docs help isolate host config vs DB vs Oban vs external dependency. | source scan + docs | `mix test test/cairnloop/docs_trust_test.exs --warnings-as-errors` | missing, Wave 0 add or extend existing docs tests. [VERIFIED: rg --files] |

### Sampling Rate

- **Per task commit:** Run the focused test file(s) for the touched boundary plus `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- **Per wave merge:** Run `mix ci.fast`; add `mix ci.integration` for schema/MCP DB-backed changes and `mix ci.quality` for docs/package changes. [VERIFIED: mix.exs:88-121]
- **Phase gate:** Run `mix ci.fast`; run `mix ci.integration` if DB-backed identity/migration tests were added; run `mix ci.quality` if docs/package output changes. [VERIFIED: CLAUDE.md; mix.exs]

### Wave 0 Gaps

- [ ] `test/cairnloop/channels/widget_socket_test.exs` - covers TRUST-02 missing verifier, explicit verifier, and no implicit accept-any-token path. [VERIFIED: rg --files]
- [ ] `test/cairnloop/chat_telemetry_test.exs` - covers TRUST-05 negative telemetry keys for conversation resolve/resolved events. [VERIFIED: rg --files]
- [ ] `test/cairnloop/web/health_plug_test.exs` - pins shallow `/health` liveness. [VERIFIED: rg --files]
- [ ] Docs/source-scan coverage for MCP module/token truth, `/health` liveness wording, Scrypath opt-in docs, and troubleshooting doctor output. [VERIFIED: codebase grep]
- [ ] If `customer_ref` is added, update schema/migration tests and mark DB-backed checks with `# REPO-UNAVAILABLE` where necessary. [VERIFIED: CLAUDE.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Host-owned operator auth via router pipelines/on_mount/session MFA; widget/email/MCP configured verifier/token seams. [VERIFIED: CLAUDE.md; guides/07-auth-and-operator-identity.md; codebase grep] |
| V3 Session Management | yes | LiveView session `host_user_id` is the operator identity source; no Cairnloop-owned session store. [VERIFIED: lib/cairnloop/router.ex:78-117] |
| V4 Access Control | yes | Governance facade for governed actions, fail-closed missing actor, MCP Bearer token before tool metadata/write surfaces. [VERIFIED: lib/cairnloop/web/conversation_live.ex:298-366, lib/cairnloop/web/mcp/router.ex:85-132] |
| V5 Input Validation | yes | Plug/Jason parsing, Ecto changesets, NimbleOptions router opts, configured verifier callbacks. [VERIFIED: codebase grep; mix.lock] |
| V6 Cryptography | yes | Do not hand-roll crypto; existing MCP token issuance uses `:crypto.strong_rand_bytes/1` and SHA-256 hash storage. [VERIFIED: lib/cairnloop/mcp.ex:15-27] |

### Known Threat Patterns for Elixir/Phoenix Embedded Library

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Spoofed widget token becomes durable operator actor | Spoofing, Elevation of Privilege | Verify widget token at socket connect and store customer identity separately from `host_user_id`. [VERIFIED: codebase grep; context] |
| Confused deputy between customer and operator identity | Spoofing, Repudiation | Use dashboard session actor for governed actions and fail closed when missing. [VERIFIED: guides/07-auth-and-operator-identity.md; codebase grep] |
| Unauthenticated MCP tool discovery | Information Disclosure | Require Bearer token before `initialize` and `tools/list` expose capabilities/tool metadata. [VERIFIED: context; CITED: https://modelcontextprotocol.io/specification/2025-11-25/server/tools] |
| Email webhook spoofing | Spoofing | Require configured token/signature verifier and halt after unauthorized response. [VERIFIED: codebase grep; CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Support content leaks through telemetry/logging | Information Disclosure | Emit bounded metadata and add negative tests for raw bodies, payloads, arbitrary metadata, and secrets. [VERIFIED: codebase grep: lib/cairnloop/chat.ex:280-338, test/cairnloop/retrieval/telemetry_test.exs:77-102] |
| Optional side-effect exfiltration | Information Disclosure, Tampering | Keep Scrypath disabled by default, validate config before enqueue, and fetch durable content only inside enabled worker path. [VERIFIED: context; codebase grep] |
| Misleading readiness | Denial of Service, Operational Risk | Keep `/health` shallow and expand Doctor with precise findings and strict mode behavior. [VERIFIED: context; codebase grep] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md` - locked decisions, deferred scope, and canonical code surfaces. [VERIFIED: local file]
- `.planning/REQUIREMENTS.md` - TRUST-01 through TRUST-05 and OPS-01 through OPS-04. [VERIFIED: local file]
- `.planning/ROADMAP.md` - Phase 58 goal and success criteria. [VERIFIED: local file]
- `.planning/STATE.md` and `.planning/PROJECT.md` - vM019 trust posture and carried architecture invariants. [VERIFIED: local file]
- `AGENTS.md`, `CLAUDE.md`, `docs/operator-ui-principles.md` - repo instructions, test gates, and UI constraints. [VERIFIED: local file]
- Codebase grep and file reads for modules/tests cited throughout this file. [VERIFIED: codebase grep]
- `mix.lock`, `mix.exs`, `mix hex.info`, `mix --version`, `elixir --version`, and environment probes. [VERIFIED: local command]

### Secondary (MEDIUM confidence)

- Phoenix LiveView Router docs - `live_session/3`, session MFA, and `on_mount` auth guidance: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html [CITED: official docs]
- Phoenix Socket docs - `connect/3` receives params and authenticates before assigning socket state: https://phoenix.hexdocs.pm/Phoenix.Socket.html [CITED: official docs]
- Plug.Conn docs - `halt/1` prevents downstream plugs; `send_resp/3` sends a response: https://hexdocs.pm/plug/Plug.Conn.html [CITED: official docs]
- telemetry docs - span start/stop metadata independence and explicit stop metadata: https://telemetry.hexdocs.pm/telemetry.html [CITED: official docs]
- Oban.Testing docs - manual mode and queued job assertions: https://hexdocs.pm/oban/Oban.Testing.html [CITED: official docs]
- MCP authorization docs - protected resource metadata and Bearer auth behavior: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization [CITED: official docs]
- MCP tools docs - tools expose model-controlled metadata: https://modelcontextprotocol.io/specification/2025-11-25/server/tools [CITED: official docs]

### Tertiary (LOW confidence)

- None used for implementation recommendations. Context7 was unavailable, so official docs were used directly. [VERIFIED: local command]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions are locked in `mix.lock`, local runtime was probed, and no package changes are recommended. [VERIFIED: local command]
- Architecture: HIGH - phase is dominated by current codebase seams and locked project decisions. [VERIFIED: codebase grep; context]
- Pitfalls: HIGH - pitfalls are tied to exact existing lines, tests, and docs drift. [VERIFIED: codebase grep]
- External protocol/docs: MEDIUM - official docs were read directly via web fallback, but Context7 MCP was unavailable. [CITED: official docs; VERIFIED: local command]

**Research date:** 2026-06-29
**Valid until:** 2026-07-29 for codebase-specific findings; re-check official MCP/Phoenix docs before planning if implementation starts after that date.
