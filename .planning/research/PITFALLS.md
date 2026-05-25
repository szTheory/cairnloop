# Pitfalls Research — vM012 Public Release & MCP Write Surface

**Domain:** Elixir library first publish, example app, MCP OAuth, MCP write tools
**Researched:** 2026-05-25
**Confidence:** HIGH (hex.pm/MCP OAuth official docs verified), MEDIUM (MCP write idempotency — emerging best practice, less official documentation)

---

## Critical Pitfalls

### Pitfall 1: Publishing with Git Dependencies

**What goes wrong:**
`mix hex.publish` hard-fails if any dependency in `mix.exs` is declared as a Git dep
(`github:`, `git:` keys). This blocks the publish entirely — you get a clear error, but
it can surprise you the first time if you added a Git dep for an unreleased dependency.

**Why it happens:**
During development it is convenient to pin unreleased or forked libraries via Git. When
publishing time arrives, the dev hasn't audited `deps` for Git entries, or an
`only: [:dev, :test]` annotation is missing, so hex treats it as a production dep.

**How to avoid:**
Before publishing: audit every entry in `mix.exs` deps. Any Git dep must either be
converted to a Hex dep (wait for an upstream release), or scoped `only: [:dev, :test]`
if it is development-only. Run `mix hex.build` locally first — it fails fast and lists
offending deps without actually uploading anything.

**Warning signs:**
- Any `{:foo, github: "..."}` or `{:foo, git: "..."}` without `only:` in deps list.
- `mix hex.build` output showing "Git dependencies are not allowed in Hex packages."

**Phase to address:**
REL phase (publish gate) — enforce via CI check that `mix hex.build` succeeds before
pushing the release tag.

---

### Pitfall 2: Accidentally Publishing Internal/Private Modules in the Public API Surface

**What goes wrong:**
`@moduledoc false` hides a module from ExDoc docs, but it does NOT make the module
private. The module's functions are still callable from outside the package. Consumers
discover and call internal modules, then break when those modules change.

**Why it happens:**
Elixir has no language-level private module concept. Authors mark modules with
`@moduledoc false` assuming it signals "do not use." It signals "do not document," not
"do not export." Because there are no compiler warnings for callers of hidden modules,
the boundary erodes silently.

**How to avoid:**
- Audit which modules you intend adopters to call. Anything not in that set gets
  `@moduledoc false`.
- Consider prefixing internal modules with a `Internal` or `Impl` segment (e.g.
  `Cairnloop.MCP.Internal.Parser`) as a strong social signal.
- Use `PrivCheck` (`{:priv_check, ~> 0.2, only: [:dev, :test]}`) in the example app's
  dependencies so that any accidental internal-module calls in demo code are caught
  at compile time.
- Document the public surface explicitly in `README.md` and top-level moduledoc.

**Warning signs:**
- Modules named `*Helper`, `*Utils`, `*Impl`, or `*Internal` without `@moduledoc false`.
- ExDoc showing modules that adopters should never touch.
- Example app referencing internal modules (would be caught by PrivCheck).

**Phase to address:**
REL phase — run `mix docs` locally before publish and review the generated index for
modules that should not be public. Add `@moduledoc false` sweep as a checklist item
in the publish runbook.

---

### Pitfall 3: Overly Tight Dependency Version Constraints Block Adopter Upgrades

**What goes wrong:**
A dep like `{:plug, "~> 1.16.1"}` prevents adopters who are already on Plug 1.17 from
using your library without a conflict. This is the single most common reason a library
gets a "dependency conflict" bug report within days of first publish.

**Why it happens:**
Using `"~> x.y.z"` (three-part) was copied from a lockfile or internal pin. The patch
component locks out minor-version upgrades of the upstream library, which is far too
restrictive for a public dependency that moves forward independently.

**How to avoid:**
- Use `"~> x.y"` (two-part) for all production dependencies in `mix.exs`. This allows
  any patch/minor upgrade while blocking major-version breaks.
- If you depend on a specific bug-fix, use `"~> x.y and >= x.y.z"` instead of the
  three-part form.
- Run a second CI workflow with `mix deps.unlock --all` to verify the library builds
  against the latest published versions of all deps.

**Warning signs:**
- Three-part `"~> x.y.z"` in `mix.exs` deps.
- Adopter GitHub issues titled "Dependency conflict with [X]" within the first week.

**Phase to address:**
REL phase — audit all deps as part of publish prep. Encode the two-part rule in CLAUDE.md
so future phases don't regress.

---

### Pitfall 4: Package Name / Module Namespace Collision

**What goes wrong:**
A `cairnloop` package name or `Cairnloop.*` module already exists on Hex, or a
namespace-adjacent package defines a `Cairnloop` top-level module. In Erlang/OTP only
one version of a module can be loaded per BEAM node, so adopters who have both packages
get silent module shadowing.

**Why it happens:**
First-time publishers check hex.pm visually but don't verify module-level collisions.
The risk is higher when the top-level module name is a common English word or generic
concept.

**How to avoid:**
- Run `mix hex.search cairnloop` before publish to verify the name is unclaimed.
- Search hex.pm for packages that define `Cairnloop.*` modules (look at their source).
- The `:name` key in `mix.exs` can differ from `:app` if a naming conflict is found;
  the OTP atom (`:app`) is what modules live under, and that is harder to change post-publish.

**Warning signs:**
- `mix hex.search cairnloop` returns any existing package.
- Any hex package whose lib tree contains a `Cairnloop` module.

**Phase to address:**
REL phase, pre-publish checklist step.

---

### Pitfall 5: Missing or Thin mix.exs Package Metadata Fails the Hex Quality Check

**What goes wrong:**
Hex publishes the package but shows warnings on the package page (or blocks the publish
in strict mode) for missing `:description`, missing `:licenses`, or an empty `:links`
map. Adopters see an incomplete package page and distrust the library. ExDocs fail to
generate properly if `source_url` is missing from `mix.exs` project config.

**Why it happens:**
The metadata fields are optional during development. First-time publishers forget to
fill them in, or they use placeholder text. The `:licenses` field requires an SPDX
identifier, not a free-form string; an invalid identifier (`"MIT License"` instead of
`"MIT"`) causes a warning.

**How to avoid:**
Required minimum before publish:
```
:description  — 1-3 sentence library summary (required)
:licenses     — ["MIT"] or other valid SPDX identifier (required)
:links        — %{"GitHub" => "https://github.com/org/cairnloop"} (required for quality)
:source_url   — same GitHub URL, in project/0 block, for ExDoc source links
:homepage_url — hex.pm package page URL or docs URL, in project/0
```
Run `mix hex.build` which reports metadata warnings before upload.

**Warning signs:**
- `mix hex.build` output containing `[warning] Missing required field`.
- ExDoc showing broken source links on function pages.

**Phase to address:**
REL phase — include a metadata completeness checklist in the publish runbook.

---

### Pitfall 6: The One-Hour Publish Revert Window

**What goes wrong:**
Hex allows reverting a published version for 60 minutes after release (or 24 hours for
the very first release of a new package). After that, a version is permanent. A botched
v0.1.0 publish with wrong metadata, a wrong `:files` list, or a bad dep constraint
cannot be quietly retracted — you can only retire or publish v0.1.1.

**Why it happens:**
Publishers move fast on release day and skip the pre-publish dry-run step. The `mix
hex.publish` command succeeds immediately; the package goes live before anyone notices
problems.

**How to avoid:**
- Always run `mix hex.build` (dry-run, produces the tarball without uploading) and
  inspect it: `tar xzf cairnloop-0.1.0.tar` and verify `contents.tar.gz` contains only
  expected files.
- Test the published package by adding it as a local Hex dep in a scratch Phoenix project
  immediately after publish, before announcing.
- Set a calendar alarm for "30 min after publish" — last chance to revert.

**Warning signs:**
- `mix hex.build` not run before `mix hex.publish`.
- `:files` key not explicitly set in `mix.exs` (default includes `priv/`, `lib/`, but
  could capture test fixtures if paths are unconventional).

**Phase to address:**
REL phase — mandatory pre-publish dry-run step in CI.

---

### Pitfall 7: Example App Path-Dep vs Hex-Dep Mismatch Breaks DEMO-04

**What goes wrong:**
The example app is developed against `{:cairnloop, path: "../"}` (path dep). This is
correct during development. Requirement DEMO-04 mandates the published example app
reference the library via the actual hex dep `{:cairnloop, "~> 0.1"}`. Forgetting to
flip this before merging means CI of the example app doesn't test the actual published
package — it tests the local source. CI may pass while the published package has a
different issue.

**Why it happens:**
Developers forget to switch the dep after hex publish. Or they switch it but forget
to run `mix deps.get` to actually fetch from hex.pm. The example app compiles from
the local path cache until explicitly cleaned.

**How to avoid:**
- Make the dep switch (`path:` → `"~> 0.1"`) part of the REL phase success criteria,
  not an afterthought.
- Add a CI job specifically for the example app that runs from a clean directory (no
  local `_build`) to catch any implicit path-dep bleedthrough.
- Run `mix deps.tree` in the example app CI step to verify cairnloop is shown as a
  fetched hex dep, not a path dep.

**Warning signs:**
- Example app `mix.deps` still shows `{:cairnloop, path: "../../"}` in the published branch.
- `mix deps.tree` in example app shows `cairnloop` as `(path)`.

**Phase to address:**
DEMO phase for path-dep switch; REL phase to verify it at publish time.

---

### Pitfall 8: Example App Scope Creep Turns Demo into a Second Product

**What goes wrong:**
The example app grows custom routes, custom schemas, custom LiveView components, and
its own business logic. It becomes a parallel implementation of the host app, not a
minimal integration showcase. Contributors then expect features in the example app that
the library doesn't expose. The example app drifts from the actual library API over
milestones and begins exercising paths the library removed.

**Why it happens:**
"Just one more thing to show" is compelling. The demo context encourages building
polished screens. There is no formal scope constraint on example apps.

**How to avoid:**
- Define the example app's scope precisely before any code is written: it demonstrates
  exactly the three flows in DEMO-02 and nothing else.
- No custom business logic not required by those three flows.
- No custom Phoenix schemas beyond what's needed to seed test data.
- Add a `SCOPE.md` to the example app root listing what it intentionally does and
  does not include.

**Warning signs:**
- Example app has more than one Phoenix context of its own.
- Example app contains LiveView components that duplicate Cairnloop's operator UI.
- Example app PRs that add "nice to have" features.

**Phase to address:**
DEMO phase — define scope gate before writing a line of code.

---

### Pitfall 9: OAuth Token Accepted in Query Parameter (Implicit/Legacy Pattern)

**What goes wrong:**
A convenience route accepts `?access_token=...` in the URL query string. The token
appears in server logs, browser history, referrer headers (when navigating away), and
any CDN/proxy access logs sitting between client and server. One log scrape exposes the
token.

**Why it happens:**
Early MCP OAuth implementations (and many tutorials) show query-parameter token passing
for simplicity. It is trivially convenient in curl and Postman. OAuth 2.0 spec allowed
it; OAuth 2.1 forbids it.

**How to avoid:**
Tokens must appear only in the `Authorization: Bearer <token>` HTTP header. Route
handlers must validate that the header is present and return 401 if absent — never fall
back to a query param.

**Warning signs:**
- Any route plug that checks `conn.params["access_token"]`.
- Test helpers passing tokens via `?access_token=` in test requests.

**Phase to address:**
MCP-02 phase — encode as a pattern-level constraint in the OAuth implementation spec.

---

### Pitfall 10: PKCE Code Verifier Stored in Persistent Storage or Re-Used Across Sessions

**What goes wrong:**
The PKCE code verifier is stored in a database, ETS table, or session cookie that
survives the auth flow. An attacker who compromises any persistent store before the
exchange can intercept and use the verifier. If challenges are not invalidated after
first use, replay attacks succeed.

**Why it happens:**
Teams use the same state-storage pattern they use for everything else (GenServer, ETS,
or DB row). They don't realize the verifier's validity window is single-use and must
end immediately after the authorization code exchange.

**How to avoid:**
- Store the code verifier only for the duration of the authorization code flow: a
  short-lived Ecto row (or Plug session) keyed on the `state` parameter, deleted on
  use and on expiry.
- The `state` parameter validates that the callback belongs to the originating request;
  the DB row for the in-flight flow is deleted on first use.
- Always use `S256` transformation, never `plain`.
- The code verifier must be generated with sufficient entropy (≥43 octets of URL-safe
  Base64, from a CSPRNG).
- After the code exchange succeeds, delete the in-flight row immediately (not lazily).

**Warning signs:**
- PKCE state stored in a table with no TTL or cleanup job.
- Code challenges not invalidated after successful exchange.
- `plain` as the challenge method anywhere in the implementation.

**Phase to address:**
MCP-02 phase — part of the OAuth flow implementation, tested with an explicit replay
attack test case.

---

### Pitfall 11: OAuth Scope Overly Broad — Token Grants More Than the Invoked Tool Needs

**What goes wrong:**
The MCP OAuth server issues a token with a generic `tools:write` scope. Any tool in
the write surface can be invoked with that token. A compromised or misdirected token
grants access to every write tool, not just the one the client intended to call.

**Why it happens:**
Designing fine-grained scopes feels over-engineered for an initial implementation.
Generic `read`/`write` scopes are the first thing developers reach for. The blast
radius of token compromise only becomes visible after more write tools are added.

**How to avoid:**
Use tool-scoped tokens from day one: `cairnloop:tool:{tool_name}:invoke`. This binds a
token to a specific tool invocation path. Add a resource indicator (RFC 8707) binding
the token to the cairnloop MCP server's audience so it cannot be replayed at a
different resource server.

When host-controlled delegation is in play (MCP-02 pattern): the host issues a
delegation token for the specific MCP session, and that token's scope is constrained
to the requesting actor's permissions — never broader.

**Warning signs:**
- Scope values like `tools:all`, `write`, `admin` in the token design.
- No audience claim in issued JWTs.
- The same token accepted by multiple distinct MCP endpoints.

**Phase to address:**
MCP-02 phase — scope vocabulary defined upfront in the authorization server design,
not added iteratively.

---

### Pitfall 12: Clock Skew Between MCP Server and Auth Server Causes Valid Token Rejection

**What goes wrong:**
The MCP server validates JWT `exp` and `nbf` claims against its system clock. The auth
server issued the token against its own clock. In containerized deployments (Docker,
Fly.io, etc.) the host clock and container clock can drift. Tokens that are technically
valid are rejected, producing sporadic 401s that are hard to reproduce.

**Why it happens:**
Clock skew is absent in development (one machine) and invisible in integration tests
(time is mocked or skew is sub-millisecond). It appears in production deployments with
multiple containers or across cloud regions.

**How to avoid:**
- Apply a configurable `leeway` (5–60 seconds) in JWT validation; the Elixir `jose` or
  `joken` libraries both support leeway parameters.
- Configure NTP on all containers/VMs.
- In CI integration tests, deliberately test with tokens where `nbf` is "now - 5s" to
  verify leeway works.

**Warning signs:**
- JWT validation with `leeway: 0` (or no leeway option specified at all).
- Sporadic 401 errors in staging that resolve on retry.

**Phase to address:**
MCP-02/MCP-03 phase — encode leeway in the token validation plug from the start.

---

### Pitfall 13: MCP Write Tool Invocations Bypass the Cairnloop Governed-Action Pipeline

**What goes wrong:**
The MCP write tool handler executes the tool action directly, bypassing `ToolProposal`
creation, the approval state machine, and `ToolExecutionWorker`. The write appears to
work but skips every guard: policy check, risk tier, at-most-once idempotency, and
durable audit trail. This is the most critical architectural pitfall in vM012.

**Why it happens:**
The MCP layer is a new code path. The temptation is to wire it up with a direct function
call to the tool's `run/3` because the approval flow "adds complexity." The existing
MCP seam has `-32601 Method Not Found` for write calls; filling that in with a direct
call is the path of least resistance.

**How to avoid:**
The MCP write tool handler must produce a `ToolProposal` (via `Cairnloop.Governance`)
and return a proposal reference to the caller — it must NOT execute inline. The response
surface tells the MCP client "proposal created, pending approval" and returns the
proposal ID. The MCP client polls or subscribes for the approval outcome. The execution
path remains exclusively through `ToolExecutionWorker`. This is a hard architectural
constraint that must be stated explicitly in the phase CONTEXT.md before any code is
written.

**Warning signs:**
- MCP write handler calling `Tool.run/3` or `ToolExecutionWorker.run/3` directly.
- MCP write test that asserts the action was executed in the same request.
- No `ToolProposal` row created by an MCP write call in integration tests.

**Phase to address:**
ACT-02 phase — first line of the implementation plan must state this constraint.

---

### Pitfall 14: Double-Approval When MCP Write Tool Triggers an Operator-Approval-Mode Tool

**What goes wrong:**
An MCP client submits a write tool call. The tool's risk tier is `:operator_approval`.
The Cairnloop approval UI asks the operator to approve. But the MCP client, not
receiving a success response, retries the call and creates a second `ToolProposal` for
the same action. The operator sees two identical pending approvals. Approving either
one may execute the action, or both executions race.

**Why it happens:**
MCP clients do not know whether a "no immediate result" response means "pending" or
"failed." Without an explicit proposal-reference in the response, clients retry. The
backend's one-active-lane invariant (existing from vM011) should prevent two active
proposals for the same operation, but only if the deduplication key correctly identifies
the duplicate.

**How to avoid:**
- The MCP write handler response must include the `proposal_id` and a status field
  `"pending_approval"` in the response so the client knows not to retry.
- The client must surface the proposal ID and poll/subscribe rather than re-submit.
- Reuse the existing one-active-lane invariant: the `ToolProposal` uniqueness constraint
  should include an MCP request origin key so that a retry of the same logical call
  returns the existing proposal rather than creating a new one.
- Document the "pending" response shape in the MCP tool's `description` field so
  clients know what to expect.

**Warning signs:**
- MCP write call returns no proposal reference to the caller.
- No idempotency key on MCP-originated proposal creation.
- Integration test that does not assert the second identical MCP call returns the
  existing proposal.

**Phase to address:**
ACT-02 phase — idempotency of MCP-originated proposals must be tested explicitly.

---

### Pitfall 15: Scope Bleeding — MCP Token Authorizes Tools That the Host Actor Cannot Invoke

**What goes wrong:**
An MCP OAuth token is issued with `cairnloop:tool:send_reply:invoke` scope. The
underlying host actor (the human operator the token represents) does not have
permission to send replies in the host app. The MCP server validates the token's OAuth
scope but skips the host-layer permission check. The action executes through a path
the operator could not have used directly in the Phoenix UI.

**Why it happens:**
OAuth scope and host-app RBAC are two separate authorization systems. The MCP OAuth
layer is new; it is easy to treat a valid token as "fully authorized" without realizing
the host-app permission layer also needs to be consulted.

**How to avoid:**
The MCP write handler must pass the host actor identity (extracted from the delegation
token or session) into `Cairnloop.Governance.propose/3` exactly as the Phoenix UI does.
The governed-action pipeline re-checks policy against the host actor at proposal time —
this is the existing behavior from vM011 for the non-MCP path and must not be bypassed
in the MCP path.

The key architectural statement: an MCP token does not grant more permissions than the
host actor identity it represents. Token scope narrows; it does not expand.

**Warning signs:**
- MCP write handler calling `propose/3` with a synthetic or nil actor, not the
  host actor from the delegation token.
- No test that verifies a valid MCP token for actor X is rejected when actor X lacks
  host-app permission.

**Phase to address:**
MCP-02 (delegation token design) + ACT-02 (actor identity threading into propose/3).

---

### Pitfall 16: OAuth Refresh Token Not Rotated — Silent Compromise Window

**What goes wrong:**
The auth server issues refresh tokens that are not rotated on use. An attacker who
obtains a refresh token can continue generating access tokens indefinitely, even after
the legitimate client has re-authenticated. Because the legitimate client still works
(using the same unrotated refresh token), the compromise goes undetected.

**Why it happens:**
Refresh token rotation is more complex than simple issuance. Teams implement issuance
first and add rotation "later." Later never comes.

**How to avoid:**
Implement refresh token rotation from the start: every use of a refresh token issues a
new refresh token and invalidates the old one. Implement "family" tracking: if a
previously invalidated refresh token is presented, revoke the entire family (all tokens
issued from that lineage). This is the standard pattern from OAuth 2.1.

**Warning signs:**
- Refresh token table has no rotation/generation counter column.
- No test that verifies presenting an already-used refresh token is rejected.
- No "family revocation" path in the token revoke endpoint.

**Phase to address:**
MCP-03 phase (OAuth token lifecycle) — design family tracking before writing the schema.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Publish v0.1.0 with placeholder CHANGELOG | Unblocks June 2 deadline | Hex.pm package page looks abandoned; adopters assume project is dead | Never — write the real CHANGELOG, it takes 2 hours |
| Use `plain` PKCE transform for "simplicity" | One fewer hash function to implement | Zero security; PKCE provides no protection | Never |
| Generic `write` OAuth scope for all tools | Faster to implement one scope | Token compromise grants access to every write tool; scope cannot be narrowed retroactively | Never in production |
| Skip `@moduledoc false` audit before publish | Faster publish | Internal modules become de facto public API; breaking changes hit adopters | Never before first publish |
| Example app stays on path dep after hex publish | No dep-switch PR needed | DEMO-04 fails; CI doesn't test actual published package | Only during active development before publish |
| Direct `Tool.run/3` in MCP write handler | Simpler code path | Bypasses all governance guards; idempotency, audit, approval all broken | Never |
| No leeway in JWT validation | Slightly tighter security posture | Spurious 401s in production under clock drift | Only in environments with guaranteed NTP sync |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| hex.pm publish | Running `mix hex.publish` without `mix hex.build` dry-run first | Always run `mix hex.build`, inspect the tarball, then publish |
| hex.pm publish | Using three-part `"~> x.y.z"` version constraint on deps | Use `"~> x.y"` (two-part) for all production deps |
| MCP OAuth / host app | Issuing MCP tokens without binding to host actor identity | Delegation tokens must encode host actor ID; propose/3 must use it |
| MCP OAuth / JWT validation | Validating signature only, not `aud` and `iss` | Validate signature + audience (RFC 8707) + issuer on every request |
| MCP write → governance | Calling tool execute directly from MCP handler | MCP handler creates ToolProposal; execution stays in ToolExecutionWorker |
| Example app / library | Example app referencing Cairnloop internal modules | Run PrivCheck in example app; fix all violations before DEMO phases |
| OAuth / Ecto token store | Storing refresh tokens without expiry or revocation column | Schema must include `revoked_at`, `family_id`, `used_at` from initial migration |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Token in query parameter | Token logged by every proxy, CDN, and browser in the path | Authorization header only; reject query-param tokens with 401 |
| `plain` PKCE transform | Code interceptor can immediately exchange the authorization code | Require `S256` only; reject `plain` at the authorization endpoint |
| MCP write without host-actor permission re-check | Privilege escalation via OAuth scope | Thread host actor through propose/3; governance pipeline re-checks policy |
| Broad OAuth scope (tools:write) | Token compromise gives full write surface access | Tool-scoped tokens from day one: `cairnloop:tool:{name}:invoke` |
| No audience validation in JWT | Token issued for one service replayed at another | Validate `aud` claim against this MCP server's URI (RFC 8707) |
| Refresh token not rotated | Silent indefinite access after token theft | Rotate on every use; revoke entire family on replay detection |
| No expiry on in-flight PKCE state | Orphaned auth flows accumulate; cleanup burden grows | TTL of 10 minutes on `oauth_states` table; Oban cleanup job |
| Publishing with non-minimal `:files` | Secrets, test keys, or internal fixtures shipped in the tarball | Explicitly enumerate `:files` in mix.exs; run `mix hex.build` and inspect |

---

## "Looks Done But Isn't" Checklist

- [ ] **Hex publish:** `mix hex.build` run and tarball inspected before `mix hex.publish` called
- [ ] **Hex publish:** All deps use `"~> x.y"` (two-part) — no `"~> x.y.z"` in production deps
- [ ] **Hex publish:** `@moduledoc false` audit done; no internal modules visible in `mix docs` output
- [ ] **Hex publish:** `:files` in mix.exs explicitly set; no test fixtures or credentials included
- [ ] **Hex publish:** `:licenses`, `:description`, `:links` all set; `mix hex.build` shows no metadata warnings
- [ ] **Example app:** `mix deps.tree` shows cairnloop as a hex dep, not a path dep
- [ ] **Example app:** PrivCheck passes — no internal Cairnloop module references in example app code
- [ ] **MCP OAuth:** PKCE uses `S256`; in-flight state rows have a TTL; used states are deleted immediately
- [ ] **MCP OAuth:** JWT validation checks signature + `aud` + `iss` + `exp` with leeway
- [ ] **MCP OAuth:** Token accepted only from `Authorization: Bearer` header (no query param fallback)
- [ ] **MCP OAuth:** Refresh tokens rotated on use; family revocation implemented
- [ ] **MCP write:** Every write tool call creates a `ToolProposal`; no direct `Tool.run/3` calls from MCP layer
- [ ] **MCP write:** Identical MCP write retries return the existing proposal, not a second one
- [ ] **MCP write:** Integration test verifies no ToolProposal created when host actor lacks permission

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Published with Git dep | LOW (within 60-min window) | `mix hex.publish --revert 0.1.0`; fix dep; republish |
| Published with Git dep (after 60 min) | MEDIUM | Publish v0.1.1 with fix; retire v0.1.0 via `mix hex.retire` |
| Published with internal modules exposed | MEDIUM | Deprecate the public internal-module surface in CHANGELOG; add `@moduledoc false`; publish next minor version |
| Published with wrong dep constraints | MEDIUM | Publish patch version (v0.1.1) with corrected constraints |
| MCP OAuth broad scope already in production | HIGH | Requires token revocation for all issued tokens, new scope vocabulary, re-auth for all clients |
| MCP write bypasses governance (if deployed) | HIGH | Requires emergency revert of the MCP write handler, token revocation, audit of all executed write calls |
| Example app scope creep | MEDIUM | Define scope gate retroactively; remove all non-demo code in a cleanup PR before public announcement |
| Refresh tokens not rotated (if deployed) | HIGH | Rotate all refresh tokens (force re-auth), add rotation column migration, implement rotation |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Git dependencies block publish | REL phase — `mix hex.build` CI gate | CI fails if build fails |
| Internal modules exposed | REL phase — `mix docs` audit + `@moduledoc false` sweep | ExDoc output contains only intended public surface |
| Overly tight dep constraints | REL phase — dep audit + `deps.unlock --all` CI job | `mix hex.build` succeeds; adopter-compatibility CI job green |
| Package name collision | REL phase — `mix hex.search` pre-publish | Search returns zero results for cairnloop |
| Missing metadata | REL phase — publish runbook checklist | `mix hex.build` shows no metadata warnings |
| One-hour revert window | REL phase — dry-run + smoke test protocol | Tarball inspected; smoke-test in scratch app succeeds |
| Path dep in example app | DEMO phase (switch) + REL phase (verify) | `mix deps.tree` shows hex dep in example app CI |
| Example app scope creep | DEMO phase — scope gate defined before coding | SCOPE.md in example app root; no custom business logic |
| Token in query parameter | MCP-02 phase | Integration test verifying query-param token returns 401 |
| PKCE verifier mishandled | MCP-02 phase | Replay attack integration test; in-flight state TTL test |
| Overly broad OAuth scope | MCP-02 phase — scope vocabulary design | Token cannot invoke tool outside its scope claim |
| Clock skew JWT rejection | MCP-02/MCP-03 phase | Integration test with time-skewed token and leeway configured |
| MCP write bypasses governance | ACT-02 phase — architectural constraint in CONTEXT.md | Integration test: every MCP write call produces a ToolProposal row |
| Double-approval on retry | ACT-02 phase | Integration test: duplicate MCP write returns existing proposal |
| Scope bleeding (MCP vs host) | MCP-02 + ACT-02 phases | Integration test: valid MCP token for actor without host permission returns 403 |
| Refresh token not rotated | MCP-03 phase | Integration test: second use of a refresh token is rejected |

---

## Sources

- [hex.pm publish documentation](https://hex.pm/docs/publish) — official file inclusion defaults, metadata requirements, revert window
- [Elixir Library Guidelines (v1.19.5)](https://hexdocs.pm/elixir/library-guidelines.html) — dep version constraints, two-part vs three-part form
- [MCP Authorization Specification (draft)](https://modelcontextprotocol.io/specification/draft/basic/authorization) — OAuth 2.1 requirements for MCP servers, PKCE requirements, resource indicators
- [MCP Tools Specification](https://modelcontextprotocol.io/legacy/concepts/tools) — tool annotations, idempotentHint, security considerations
- [RFC 8707 Resource Indicators for OAuth 2.0](https://www.rfc-editor.org/rfc/rfc8707.html) — audience binding requirement
- [MCP OAuth 2.1: PKCE, Scopes & Token Management — Practical DevSecOps](https://www.practical-devsecops.com/mcp-oauth-2-1-implementation/) — PKCE verifier storage pitfalls, scope design, token-in-query-param ban
- [Descope: Top 6 MCP Vulnerabilities](https://www.descope.com/blog/post/mcp-vulnerabilities) — scope bleeding, write surface risks
- [PrivCheck hex package](https://hexdocs.pm/priv_check/readme.html) — catching accidental internal module usage in consumers
- [Elixir Writing Documentation](https://hexdocs.pm/elixir/writing-documentation.html) — @moduledoc false semantics (hides from docs, does not make private)
- [OAuth 2.1 + PKCE for MCP Gateways — STOA Docs](https://docs.gostoa.dev/blog/oauth-pkce-mcp-gateway) — clock skew, family-level refresh token revocation

---
*Pitfalls research for: vM012 Public Release & MCP Write Surface — Cairnloop*
*Researched: 2026-05-25*
