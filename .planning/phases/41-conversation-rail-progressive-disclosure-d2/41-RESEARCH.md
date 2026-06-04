# Phase 41: Conversation Rail Progressive Disclosure (D2) - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView native-`<details>` progressive disclosure + testable-seam analysis for client-side state
**Confidence:** HIGH (testable seams verified against the actual codebase; JS API verified against deps + official docs)

## Summary

Phase 41 is design-locked (CONTEXT.md D-01..D-09, UI-SPEC.md). The only genuinely open
question is the **validation architecture**: how to prove, in Elixir/Phoenix LiveView, that
a phase whose headline success criterion ("a `<details>` survives a PubSub re-render without
snapping shut") concerns *client-owned* state the server never sees.

The decisive finding: this codebase already renders `governed_action_card/1` **headlessly**
via `render_component(Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1), proposal: proposal)`
with plain `%Cairnloop.Governance.ToolProposal{}` struct fixtures and **no Repo round-trip**
(`test/cairnloop/web/conversation_live_test.exs:1622-1702`). Every server-side rail assertion this
phase needs — static `open` presence/absence, `phx-update="ignore"`, `data-tier="2"`, group
markup, Tier-1-never-in-`<details>` — is provable in this fast, DB-free path. The `cl_disclosure`
primitive already has its "no server assign controls open" unit tests
(`components_test.exs:258-314`); Phase 41 extends, not invents, that pattern.

The PubSub-survival criterion is **not** literally server-testable (the open/closed toggle is a
browser-native `<details>` interaction the LiveView never receives), so the correct, honest proxy
is a **structural invariant assertion**: the server render for a Tier-2 group must carry
`phx-update="ignore"` AND must never bind `open` to an assign (only the static initial-render
boolean). If those two facts hold, the LiveView client *cannot* snap the panel shut — that is the
mechanism, and asserting the mechanism is the correct coverage floor. The genuinely client-only
pieces (localStorage density round-trip, `JS` `set_attribute` actually toggling `open` in a real
browser) are **out of server-test scope**; the accepted floor is markup-presence + JS-command-shape
assertions, with a browser/E2E layer explicitly deferred.

**Primary recommendation:** Build all Phase 41 validation as **headless `render_component`
component tests** in the default (DB-free) suite, asserting the *structural mechanism* (`phx-update="ignore"`,
static-only `open`, `data-tier` scoping, Tier-1-outside-`<details>`) rather than attempting to
observe client toggle state. No new test infrastructure is needed; no `# REPO-UNAVAILABLE` markers
are required for the rail-render tests.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tier-1 always-visible quartet + pending footer | Server render (HEEx) | — | Pure markup; server owns what is *outside* `<details>` |
| Tier-2/3 open/closed toggle | Browser (native `<details>`) | — | D2 invariant: server never owns open state |
| `phx-update="ignore"` patch-safety | Server render (attribute) | Browser (LiveView DOM patcher honors it) | Server emits the attribute; client patcher skips the subtree |
| Auto-expand on initial render | Server render (static `open` boolean) | — | Computed from proposal state at first render only (D-08/D-09) |
| Expand-all / Collapse-all | `Phoenix.LiveView.JS` (client) | Server render (emits the `phx-click={JS...}` markup) | Client-side DOM op on `[data-tier="2"]`; no server event |
| Density persistence | Browser (`localStorage` + JS hook) | Server render (emits `data-density` default + hook mount point) | Per UIC/D-05 a small client hook reads/writes; CSS attribute selector does the styling |

## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01..D-09 — verbatim)
- **D-01:** Nest Tier-3 inside its owning Tier-2 group; do not pool into one "raw" bucket. The
  three existing nested raw expanders are already correct/D-22-compliant — keep them where they are
  (raw input snapshot inside Inputs & scope `:1001`; per-event reason/metadata inside History `:1018`;
  raw policy snapshot inside Policy explanation `:1048`).
- **D-02:** Move the always-visible trace-id `dl` (`:1056-1063`) into a standalone collapsed Tier-3
  group ("Identifiers & trace") via its own `cl_disclosure`, default closed.
- **D-03:** `phx-update="ignore"` on a Tier-2 group covers its whole subtree; nested Tier-3
  expanders inside an ignored Tier-2 group need no additional guard. Only the standalone Trace group
  needs its own `cl_disclosure`/`phx-update="ignore"`. All 3 named Tier-2 groups + Trace group render
  via `cl_disclosure/1`.
- **D-04:** Density = spacing only, orthogonal to open-state. `comfortable` (default) ↔ `compact`
  via a `data-density` attribute on the rail container + CSS. Does NOT drive default open/closed.
- **D-05:** Rail-scoped, persisted in `localStorage` (suggested key `cl:rail:density`), applied on
  mount via a small JS hook. Cockpit-wide density deferred.
- **D-06:** Expand-all/Collapse-all operates on Tier-2 groups ONLY (`data-tier="2"`); nested Tier-3
  and the Trace group untouched.
- **D-07:** Collapse-all MAY collapse a blocking card's Tier-2; Tier 1 stays visible regardless.
- **D-08:** Auto-expand fires for pending-approval (`active_approval.status == :pending`) OR hard-block
  (`block_reason` = `scope_invalid`/`policy_denied`) cards — static `open` at initial render on Inputs
  & scope; when `policy_denied`, also static-open Policy explanation.
- **D-09:** Initial-render-only — NO PubSub re-snap-open (locked invariant; do not "fix" by adding an
  assign).

### Carried-forward invariants (do not re-litigate)
- **D2 (vM016):** native `<details>`/`<summary>` for all per-card disclosure; no server assigns bind
  open state; `Phoenix.LiveView.JS` only for rail-level controls + localStorage density.
- **Phase 37 D-03:** `cl_disclosure/1` is the primitive; `open` is the static HTML attribute at
  initial render only.
- **Phase 40:** prefer migrating bespoke `<details style=…>` to `cl_disclosure`.
- **Brand §7.5:** never state-by-color-alone.

### Claude's Discretion
- Exact `data-*` attribute names, localStorage key string, CSS class names.
- Single rail header control cluster (recommended) vs separate placements.
- Precise per-state choice of which Tier-2 group(s) auto-open (within D-08 trigger set).
- Whether the draft card gains the same accordion or only the Tier-1 quartet.

### Deferred Ideas (OUT OF SCOPE)
- Cockpit-wide density preference (P42+).
- Persisting individual panel open/closed state across refresh.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RAIL-01 | Tier 1 (headline + status + safety quartet + pending footer) never collapses | Provable headlessly: assert the quartet/footer markup renders *outside* any `<details>` (structural assertion — see Validation Architecture §"Tier-1 isolation"). `governed_action_card/1` already renders these unconditionally at `conversation_live.ex:960-980, 1068`. |
| RAIL-02 | Tier 2/3 in native `<details>` with no assigns-bound open, surviving PubSub | Provable via *mechanism* assertion: each Tier-2/3 group carries `phx-update="ignore"` and emits `open` only as a static boolean. `cl_disclosure/1` already guarantees this (`components.ex:198-205`); existing tests at `components_test.exs:258-314`. The literal "survives a live re-render" is asserted structurally, not by observing client toggle. |
| RAIL-03 | Auto-expand + Expand/Collapse-all + remembered density via `JS`, never touching Tier 1 | Auto-expand provable headlessly (positive: pending→`open`; negative invariant: render is a *pure function of proposal state*, so "becomes pending mid-session" cannot differ from "is pending at render" in a single render — see §"Auto-expand testing" for the honest framing). `JS` command shape (`set_attribute`/`remove_attribute` targeting `[data-tier="2"]`) provable as rendered `phx-click` markup. Density localStorage round-trip is client-only → markup-presence floor. |

## Standard Stack

### Core (already present — nothing to install)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | 1.1.30 | LiveView render + `Phoenix.LiveView.JS` client commands + `Phoenix.LiveViewTest` | Already the project's UI layer; `JS.set_attribute/remove_attribute` with CSS `to:` selectors verified present (`deps/phoenix_live_view/lib/phoenix_live_view/js.ex:792-828`) [VERIFIED: deps source] |
| `lazy_html` | 0.1.x | LiveView 1.1's test-time HTML parser (replaces Floki for `Phoenix.LiveViewTest`) | Already a transitive dep via LV 1.1; `render_component` returns HTML strings the existing tests `=~`-match without needing structured parsing [VERIFIED: mix.lock] |
| `ex_unit` | bundled | `use ExUnit.Case, async: true` headless component tests | Existing `components_test.exs` / `conversation_live_test.exs` idiom [VERIFIED: codebase] |

**No new dependencies.** This phase installs nothing.

### Test-render seams (verified in this repo)
| Seam | Where | Use |
|------|-------|-----|
| `render_component(&fun/1, assigns)` | `conversation_live_test.exs:1492, 1656` | Render `governed_action_card/1` headlessly with a `%ToolProposal{}` fixture — **no Repo** |
| `Function.capture(Mod, :fun, 1)` + `render_component` | `conversation_live_test.exs:1655` | Runtime dispatch render of the card (the established card-test idiom) |
| `rendered_to_string(~H"...")` | `components_test.exs:16, 264` | Render `cl_disclosure/1` in isolation (the primitive unit-test idiom) |
| `tool_proposal_fixture/1` | `conversation_live_test.exs:1622` | Plain-struct fixture builder; merge overrides for status/approval/block state — **no DB** |

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. All libraries (`phoenix_live_view`,
`lazy_html`, `ex_unit`) are pre-existing project dependencies verified present in `mix.lock`.

## Architecture Patterns

### Data-flow (what is server-owned vs client-owned)

```
proposal struct (ToolProposal)
        │
        ▼
governed_action_card/1  ──(pure function of proposal state)──▶  HEEx render
        │                                                            │
        │  Tier 1: quartet + pending footer ─────────────────────────┼──▶ ALWAYS outside <details>
        │                                                            │
        │  Tier 2/3 groups via cl_disclosure ────────────────────────┼──▶ <details phx-update="ignore"
        │     • static open={pending? || policy_denied?}             │       open={static boolean only}
        │     • data-tier="2" on named groups                        │       id="ga-#{id}-inputs" ...
        ▼                                                            ▼
   (server diff on PubSub)                                   browser native <details> toggle
        │                                                            │
        │  LiveView DOM patcher sees phx-update="ignore" ───────────▶│  subtree NOT patched
        │  → open/closed state untouched by re-render                │  → survives reload (RAIL-02)
        ▼                                                            ▼
   rail-level controls render JS commands:                  Phoenix.LiveView.JS executes client-side:
   phx-click={JS.set_attribute({"open",""}, to: "[data-tier='2']")}  set/remove open attr; persists
   phx-click={JS.remove_attribute("open", to: "[data-tier='2']")}    across server patches
```

### Pattern 1: `cl_disclosure/1` from inside the card template
**What:** Replace each bespoke `<details style=…>` with `<.cl_disclosure id=... open={...}>` + a
`:summary` slot. The primitive already emits `class="cl-details cl-disclosure" phx-update="ignore"`.
**When:** All 4 groups (3 Tier-2 + standalone Trace).
**Signature gotcha:** `cl_disclosure/1` requires `id` (mandatory) and a `:summary` slot
(`components.ex:193-196`). IDs must be stable + unique per card — derive from `proposal.id`
(e.g. `"ga-#{@proposal.id}-inputs"`). The `inner_block` is the body; per the P41 forward-compat
guardrail in the doc (`components.ex:189-191`), **live-updating content must stay outside** the
`<details>` — but the rail body is snapshot-derived (P14 D-02 plain-assign render), so this is
already satisfied.

```elixir
# Source: components.ex:198-205 (the primitive); call site is the card template
<.cl_disclosure id={"ga-#{@proposal.id}-inputs"} open={@auto_open_inputs} data-tier="2">
  <:summary>Inputs &amp; scope</:summary>
  <%!-- humanized rows + nested Tier-3 raw snapshot (already D-22 compliant) --%>
</.cl_disclosure>
```

**`data-tier` gotcha:** `cl_disclosure/1` as written (`components.ex:193-196`) declares only
`:id`, `:open`, `:summary`, `:inner_block` — it has **no `:rest`/global attr passthrough**. Passing
`data-tier="2"` will NOT reach the `<details>` element. The planner must choose one of:
  - **(Recommended)** Add `attr(:rest, :global)` to `cl_disclosure/1` and spread `{@rest}` onto the
    `<details>` — minimal, additive, keeps the primitive generic. This is a Phase-37-component edit;
    flag it because P37 is sealed (CLAUDE.md "seal completed phases" → prefer additive; adding a
    `:global` passthrough is purely additive and does not churn existing behavior).
  - Or add an explicit `attr(:tier, :string, default: nil)` and conditionally emit `data-tier`.
  The recommended `:rest` approach also lets the auto-generated `id` carry `data-density` mount
  hooks if needed without further edits.

### Pattern 2: Rail-level JS controls (no server event)
**What:** Expand-all/Collapse-all are pure client DOM ops; no `handle_event`.
```elixir
# Expand all Tier-2 groups in the rail (does NOT touch Tier-3 / Trace — no data-tier there)
<.cl_button variant="ghost" size="sm"
  phx-click={JS.set_attribute({"open", ""}, to: "[data-tier='2']")}>Expand all</.cl_button>
<.cl_button variant="ghost" size="sm"
  phx-click={JS.remove_attribute("open", to: "[data-tier='2']")}>Collapse all</.cl_button>
```
`JS.set_attribute({"open", ""}, ...)` sets the boolean `open` attribute (empty value renders as
present); `remove_attribute` clears it. The `open` attribute on `<details>` is a *reflected* boolean
attribute (not a JS-only DOM property), so `set_attribute` works on it — unlike the input `value`
caveat called out in the LV docs (`js.ex:799`). JS-applied DOM ops persist across server patches
[CITED: hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html].

### Pattern 3: Density via colocated hook (library-shipping caveat — IMPORTANT)
**What:** A small JS hook reads/writes `localStorage["cl:rail:density"]` and applies
`data-density` to `.evidence-rail` on mount. CSS attribute selectors (`[data-density="compact"]`)
do the actual styling with no flash (UI-SPEC §"Density CSS Contract").

**Library-shipping gotcha (HIGH-impact, flag to planner):** Cairnloop is a **host-owned library**,
not an app. JS hooks in a library are shipped via **LiveView 1.1 colocated hooks** — a
`<script :type={Phoenix.LiveView.ColocatedHook} name=".RailDensity">` block emitted next to the
component. BUT the example app currently imports only `phoenix-colocated/cairnloop_example`
(its *own* namespace) — `examples/cairnloop_example/assets/js/app.js:25`. A library hook lands in
`phoenix-colocated/cairnloop` (the **library** app name, `mix.exs:6` `app: :cairnloop`), which the
consuming app does **not** import today. So a colocated density hook will compile but **silently not
load** in the example app until the consumer adds `import {hooks} from "phoenix-colocated/cairnloop"`
and merges it into `LiveSocket` `hooks:`. The planner must either:
  1. Ship the colocated hook AND add the consumer-side import to `examples/cairnloop_example/assets/js/app.js`
     (and document it for downstream adopters), or
  2. Treat the density hook as **adopter-wired** (document the required JS in README; the library
     ships only the markup contract + CSS), consistent with the host-owned posture.
  Decide-for-me default (per CLAUDE.md shift-left + adopter-first lens): **ship the colocated hook,
  wire the example app's app.js, and document the import for adopters** — this is the only option
  that produces a "real ship" the example app demonstrates. The density CSS + `data-density` default
  attribute are server-rendered and testable regardless of which option is chosen.

### Anti-Patterns to Avoid
- **Adding an assign to "fix" mid-session auto-expand.** D-09 locks this out. Never introduce
  `open={@something_dynamic}` that changes after mount.
- **Putting any live-updating content inside an ignored `<details>`.** The `phx-update="ignore"`
  subtree is frozen after mount (`components.ex:189-191`). Rail bodies are snapshot-derived so this
  is fine, but do not move a live timer/status into a Tier-2 body.
- **Relying on `data-tier` passthrough without a `:global` on `cl_disclosure`.** See Pattern 1.
- **Asserting client toggle state in a server test.** The server never sees it; assert the mechanism.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Patch-safe disclosure | New `<details>` + manual `phx-update` | `cl_disclosure/1` (`components.ex:198`) | Already encodes ignore + static-open invariant + CSS classes |
| Trace `dl` body | Bespoke `governed-action-trace` `<dl>` | `cl_fact_list/1` (`components.ex:217`) | D-02 target; already styled, auto-escaped |
| Expand/collapse JS | Custom JS hook for toggling | `Phoenix.LiveView.JS.set_attribute`/`remove_attribute` | Built-in, patch-aware, no custom JS to test |
| Card-render test harness | New LiveView mount + Repo seeding | `render_component(Function.capture(...), proposal: fixture)` | Existing headless idiom, DB-free, fast |

**Key insight:** Every "new" capability this phase needs already has a primitive. The phase is
restructuring + ~one additive `:global` on `cl_disclosure` + CSS + (optionally) one colocated hook.

## Runtime State Inventory

> Rename/refactor-adjacent (markup migration). Categories checked explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **None** — no datastore keys/collections change; `data-density` lives only in browser `localStorage`, not any server datastore. Verified: no Repo schema touched by this phase. | none |
| Live service config | **None** — no external service (n8n/Datadog/etc.) configuration references the rail markup. | none |
| OS-registered state | **None** — no OS-level registrations involved. | none |
| Secrets/env vars | **None** — no secret or env var names change. | none |
| Build artifacts | **localStorage key `cl:rail:density`** is a new client-persisted value; **`phoenix-colocated/cairnloop` import** must be wired into the consuming app's `app.js` if the colocated hook is shipped (see Pattern 3). No compiled-artifact rename. | wire example app's `app.js` import IF colocated hook ships |

**The canonical question (after every file is updated, what runtime state persists the old shape?):**
Only the browser's `localStorage` density preference and native `<details>` open state — both are
*new* (no prior value to migrate) and both are deliberately client-owned (D-04/D-05). Nothing
server-side caches rail markup.

## Common Pitfalls

### Pitfall 1: `data-tier` silently dropped by `cl_disclosure/1`
**What goes wrong:** Expand-all/Collapse-all target `[data-tier="2"]`, but the attribute never
reaches the `<details>` because `cl_disclosure/1` has no global-attr passthrough.
**Why it happens:** The P37 primitive declares only `:id/:open/:summary/:inner_block`.
**How to avoid:** Add `attr(:rest, :global)` (additive, doesn't churn sealed behavior) and spread it
onto `<details>`; add a test asserting `data-tier="2"` appears in the rendered Tier-2 group markup.
**Warning sign:** Expand-all "does nothing" in the browser even though the buttons render.

### Pitfall 2: Density hook silently inert (library/app namespace mismatch)
**What goes wrong:** The colocated density hook compiles but never fires because the consuming app
imports `phoenix-colocated/cairnloop_example`, not `phoenix-colocated/cairnloop`.
**Why it happens:** Host-owned library; colocated hooks namespace by the *defining* app (`:cairnloop`).
**How to avoid:** Wire the example app's `app.js` import + document for adopters (Pattern 3 default).
**Warning sign:** `data-density` never changes; localStorage stays empty after clicking the toggle.

### Pitfall 3: Treating "survives PubSub" as observable in a server test
**What goes wrong:** A test tries to mount the LiveView, open a panel, push a reload, and assert it's
still open — but the server has no record of "open", so the assertion is meaningless/un-writable.
**Why it happens:** Open state is browser-native; `Phoenix.LiveViewTest` asserts *server-rendered*
HTML, not client DOM toggle state.
**How to avoid:** Assert the **mechanism**: `phx-update="ignore"` present + `open` only ever a static
boolean. If those hold, the client patcher *cannot* close the panel. Document this as the deliberate
proxy in VALIDATION.md.
**Warning sign:** A test name like "panel stays open after reload" with no clear assertion target.

### Pitfall 4: Boolean-attr leakage in `open={false}`
**What goes wrong:** A non-pending card accidentally emits `open`.
**Why it happens:** Passing a truthy non-boolean to `open`.
**How to avoid:** `open` must be a real boolean assign; HEEx omits the attribute on `false`
(already proven at `components_test.exs:298`). Test the negative: non-pending card → `refute html =~ ~r/\bopen\b/` on the Tier-2 subtree.

## Code Examples

### Auto-expand positive + negative (headless, DB-free)
```elixir
# Source: idiom from conversation_live_test.exs:1622-1700
test "pending approval card auto-opens Inputs & scope at initial render (D-08)" do
  approval = %Cairnloop.Governance.Approval{id: 7, status: :pending}
  proposal = tool_proposal_fixture(%{status: :proposed, approval: approval})
  card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
  html = render_component(card_fn, proposal: proposal)
  # static open present on the inputs group
  assert html =~ ~r/data-tier="2"[^>]*open|open[^>]*data-tier="2"/  # inputs group carries open
end

test "non-pending, non-blocked card renders Tier-2 groups CLOSED (D-08 negative)" do
  proposal = tool_proposal_fixture(%{status: :proposed, approval: nil})  # no pending, no block
  card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
  html = render_component(card_fn, proposal: proposal)
  # no Tier-2 group emits a static open
  refute html =~ ~r/data-tier="2"[^>]*\bopen\b/
end
```

### The D-09 invariant as a *render-purity* assertion (the honest framing)
```elixir
# D-09 says a card that BECOMES pending mid-session must NOT auto-snap open. The render is a pure
# function of proposal state, so the testable invariant is: open is computed ONLY from the static
# render inputs, never re-applied. The strongest server-side proof is structural: there is no
# handle_event / assign path that flips open.
test "governed_action_card source binds `open` only to a render-time computation, never an event" do
  src = File.read!("lib/cairnloop/web/conversation_live.ex")
  # no handle_event re-opens a panel; no assign named to dynamically drive open after mount
  refute src =~ ~r/handle_event.*open/s          # no event toggles open server-side
  # (companion: cl_disclosure unit test already proves open is static-only — components_test.exs:283)
end
```

### Tier-1 isolation (RAIL-01) — quartet/footer outside any `<details>`
```elixir
test "pending footer renders OUTSIDE any <details> (RAIL-01, expand/collapse can't hide it)" do
  approval = %Cairnloop.Governance.Approval{id: 7, status: :pending}
  proposal = tool_proposal_fixture(%{approval: approval})
  card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
  html = render_component(card_fn, proposal: proposal)
  # The footer marker text appears, and the substring before it contains no unclosed <details>.
  assert html =~ "Approval required"
  # structural: split on the footer marker; the footer segment must not be inside a <details> scope.
  # (Practically: assert the footer's container class is a Tier-1 sibling, e.g. "governed-action-footer"
  #  is not nested under a cl-disclosure — assert ordering/sibling-ness via lazy_html if needed.)
end
```

### `cl_disclosure` "no server assign controls open" (success criterion 4) — already exists, extend
```elixir
# Source: components_test.exs:283-300 (already present). Phase 41 ADDS the card-level counterpart:
test "every rail <details> carries phx-update=ignore and binds open only as a static boolean" do
  proposal = tool_proposal_fixture(%{status: :proposed})
  card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
  html = render_component(card_fn, proposal: proposal)
  # count of <details> == count of phx-update="ignore" (every disclosure is patch-safe)
  details_count = html |> String.split("<details") |> length() |> Kernel.-(1)
  ignore_count  = html |> String.split(~s(phx-update="ignore")) |> length() |> Kernel.-(1)
  assert details_count == ignore_count
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bespoke `<details style=…>` inline expanders | `cl_disclosure/1` primitive | Phase 37 | Migrate `:1001/:1018/:1048` + new Trace group |
| Library JS via manual `app.js` Hooks object | LiveView 1.1 colocated hooks (`Phoenix.LiveView.ColocatedHook`) | LV 1.1 (this repo is on 1.1.30) | Density hook can colocate, BUT consumer must import the library namespace (Pattern 3) |
| Always-visible trace `dl` | Collapsed Tier-3 "Identifiers & trace" group | Phase 41 (D-02) | RAIL-02 compliance |

**Deprecated/outdated:** Floki as the LiveViewTest parser — LV 1.1 uses `lazy_html`. If a test needs
structured DOM traversal (e.g. asserting sibling-ness for Tier-1 isolation), use `Phoenix.LiveViewTest`
helpers (`Floki`-style `find/2` is still exposed through LiveViewTest) rather than adding Floki directly.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Approval` struct has `id` + `status` fields shaped `%Approval{status: :pending}` for fixtures | Code Examples | LOW — planner verifies exact struct in `Cairnloop.Governance`; fixture field names may differ. Easy to correct at plan time. |
| A2 | The card render is a pure function of `proposal` (no hidden assign re-reads open) | Validation Architecture / D-09 framing | LOW — confirmed by reading `:839-955` assign block (all values snapshot-computed); planner should re-confirm no `open`-driving assign is added. |
| A3 | Adding `attr(:rest, :global)` to `cl_disclosure/1` is acceptably "additive" under the seal-completed-phases rule | Pattern 1 / Pitfall 1 | LOW — purely additive passthrough; does not change existing render for existing call sites. Flag in CONTEXT ratification per CLAUDE.md. |
| A4 | The example app is the intended "real ship" surface for the density hook | Pattern 3 default decision | MEDIUM — if adopter-wired-only is preferred, the colocated hook + app.js edit are dropped in favor of README docs. This is a product-scope call the owner may want to confirm (adopter-first lens). |

## Open Questions

1. **Density hook: ship colocated + wire example app, or document-only for adopters?**
   - What we know: host-owned library; LV 1.1 colocated hooks exist; example app imports only its own
     colocated namespace.
   - What's unclear: whether the owner wants the library to inject JS (requires consumer import) vs.
     keep JS adopter-owned (README contract only).
   - Recommendation (decide-for-me default): ship the colocated hook + wire `examples/.../app.js` +
     document the import — it is the only option yielding a demonstrable real ship. Flag in the
     phase summary so the owner can cheaply veto toward document-only.

2. **Browser/E2E coverage for localStorage round-trip + actual `open` toggle — in scope?**
   - What we know: no Wallaby/E2E layer exists in this repo (no browser-driver dep in mix.lock).
   - Recommendation: **out of scope** for Phase 41. The accepted coverage floor is markup-presence +
     JS-command-shape + mechanism assertions (all headless). A browser layer is its own infra phase;
     do not block this phase on it. State this explicitly in VALIDATION.md.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `phoenix_live_view` | All rail render + `JS` commands | ✓ | 1.1.30 | — |
| `lazy_html` | LiveViewTest HTML parsing | ✓ | 0.1.x (transitive) | string `=~` matching (already used) |
| `Cairnloop.Repo` (Postgres) | NONE of the Phase 41 rail-render tests | ✗ (may be unavailable per CLAUDE.md) | — | **Not needed** — all rail tests are headless `render_component` with struct fixtures |
| Browser driver (Wallaby/Playwright) | localStorage round-trip + real `open` toggle | ✗ (no dep) | — | Markup-presence + JS-command-shape floor (deferred to a future E2E phase) |

**Missing dependencies with no fallback:** None that block this phase.
**Missing dependencies with fallback:** Browser driver → markup-presence floor (accepted). Repo →
not required (headless path).

## Validation Architecture

> Nyquist validation is **ENABLED** (`.planning/config.json` has no `workflow.nyquist_validation`
> key → treat as enabled). This section seeds VALIDATION.md.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (`use ExUnit.Case, async: true` for component tests) + `Phoenix.LiveViewTest` |
| Config file | none custom — standard `test/test_helper.exs` |
| Quick run command | `mix test test/cairnloop/web/components_test.exs test/cairnloop/web/conversation_live_test.exs` |
| Full suite command | `mix test` (default; **excludes `:integration`** — see MEMORY note) |
| Integration lane | `mix test.integration` (CI-only lane; not needed for Phase 41 — no DB round-trip) |
| Build gate | `mix compile --warnings-as-errors` (mandatory per CLAUDE.md) |

**Repo caveat (CLAUDE.md):** `Cairnloop.Repo` may be unavailable in this workspace. **No Phase 41
rail-render test needs it** — `governed_action_card/1` renders from a plain `%ToolProposal{}` struct
fixture via `render_component`. Therefore **no `# REPO-UNAVAILABLE` markers are required** for this
phase's validation tests. (If the planner adds any test that mounts the full LiveView via `live/2`
and hits `MockRepo`, that path is also DB-free — `MockRepo` is a pure in-memory stub, not Postgres.)

### What is server-testable vs. client-only (the honest boundary)

| Success criterion / requirement | Server-testable? | Assertion strategy |
|----|----|----|
| Tier-1 never collapses (RAIL-01) | **YES** | Assert quartet + pending footer markup renders *outside* any `<details>` (structural sibling assertion) |
| 3 separate Tier-2 `<details>` (Inputs/History/Policy) | **YES** | Assert 3 `cl_disclosure` groups present with `data-tier="2"` + correct summaries |
| Trace moved to standalone collapsed Tier-3 (D-02) | **YES** | Assert "Identifiers & trace" `cl_disclosure` present, default-closed (no `open`), and NOT `data-tier="2"` |
| Survives PubSub re-render (RAIL-02) | **PROXY** | Assert each rail `<details>` carries `phx-update="ignore"` AND `open` is static-only (mechanism assertion — see Pitfall 3) |
| Auto-expand pending/blocked at initial render (D-08) | **YES (positive)** | Pending/blocked fixture → Inputs group emits static `open`; `policy_denied` → Policy group also `open` |
| No mid-session re-snap-open (D-09) | **PROXY (render-purity)** | Source assertion: no `handle_event`/assign flips `open`; companion `cl_disclosure` static-only unit test |
| Expand-all/Collapse-all via `JS`, not touching Tier 1/3 (RAIL-03) | **PARTIAL** | Assert rendered `phx-click` carries `JS.set_attribute({"open",""})`/`remove_attribute("open")` scoped to `[data-tier="2"]`; assert Tier-3/Trace lack `data-tier` |
| `cl_disclosure` proves no server assign controls open (criterion 4) | **YES (exists)** | `components_test.exs:283-300` already; extend with card-level "every `<details>` is patch-safe" test |
| Density localStorage round-trip + applied on mount (RAIL-03) | **NO (client-only)** | Floor: assert `data-density="comfortable"` default attribute + toggle control markup + (if shipped) colocated hook script present. localStorage round-trip = deferred E2E. |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RAIL-01 | Quartet + pending footer render outside `<details>` | component (headless) | `mix test test/cairnloop/web/conversation_live_test.exs -k tier1` | ❌ Wave 0 (new tests; file exists) |
| RAIL-02 | 3 Tier-2 + Trace groups all `phx-update="ignore"`, static-open only | component (headless) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 |
| RAIL-02 | `cl_disclosure` static-only `open` (criterion 4) | component (headless, primitive) | `mix test test/cairnloop/web/components_test.exs` | ✅ exists (`:258-314`) — extend |
| RAIL-03 | Auto-expand positive (pending/blocked) + negative (non-pending closed) | component (headless) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 |
| RAIL-03 | D-09 no-resnap render-purity (source/structural) | component + source-grep | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 |
| RAIL-03 | Expand/Collapse-all `JS` command shape scoped to `[data-tier="2"]` | component (headless, markup) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 |
| RAIL-03 | Density default `data-density` + control markup (localStorage round-trip deferred) | component (headless, markup floor) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/components_test.exs test/cairnloop/web/conversation_live_test.exs` (fast, DB-free) + `mix compile --warnings-as-errors`.
- **Per wave merge:** `mix test` (full default suite). Note baseline flakes per MEMORY (OutboundWorkerTest, a SettingsLive order-flake) — verify-in-isolation, do not count as regressions.
- **Phase gate:** full default suite green + warnings-clean build before `/gsd:verify-work`. `mix test.integration` is NOT required (no DB/integration surface in this phase).

### Wave 0 Gaps
- [ ] `test/cairnloop/web/conversation_live_test.exs` — add a `describe "governed_action_card/1 — Phase 41 rail disclosure"` block covering: Tier-1 isolation (RAIL-01), 3 Tier-2 groups + Trace group structure (RAIL-02), every-`<details>`-is-`phx-update=ignore` (RAIL-02), auto-expand positive/negative (D-08), D-09 render-purity, Expand/Collapse-all `JS` shape, density default + control markup (RAIL-03).
- [ ] `test/cairnloop/web/components_test.exs` — extend the existing `cl_disclosure` block IF a `:rest`/`data-tier` passthrough is added to the primitive (assert `data-tier="2"` reaches the `<details>`).
- [ ] Fixture extension: `tool_proposal_fixture/1` may need an `approval:` override path for the pending-auto-expand case (the builder at `:1622` already merges arbitrary overrides — likely no change needed; confirm the `:approval` assoc shape).
- [ ] Framework install: **none** — ExUnit + LiveViewTest present.

*Browser/E2E layer (localStorage round-trip, real `open` toggle) is explicitly OUT of Wave 0 and out of Phase 41 scope; markup-presence + mechanism assertions are the accepted floor.*

## Security Domain

> `security_enforcement` not disabled in config → applies. This phase is UI restructuring with no new
> auth/crypto/data-flow surface.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | unchanged — no auth surface touched |
| V3 Session Management | no | unchanged |
| V4 Access Control | no | unchanged — rail renders already-authorized proposal data |
| V5 Input Validation / Output Encoding | **yes** | HEEx auto-escaping for all rail values; `cl_fact_list` documented to never use `raw/1` (`components.ex:212`). Raw snapshots use `inspect/2` (not `raw/1`) behind D-22 expanders — no untrusted HTML injection. |
| V6 Cryptography | no | none |

### Known Threat Patterns for Phoenix LiveView rail markup
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| XSS via unescaped proposal/snapshot content in a `<details>` body | Tampering/Info-disclosure | HEEx `{...}` auto-escaping; `inspect(..., pretty: true)` in `<pre>` (string, escaped); never `raw/1` — already the established D-22 pattern |
| Trace-id / raw-snapshot exposure to operators by default | Info-disclosure | D-02/D-22 masking choke point — Tier-3 raw content only behind explicit (default-closed) expanders; this phase *strengthens* it by collapsing the previously-always-visible trace `dl` |

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/cairnloop/web/components.ex:180-227` (cl_disclosure, cl_fact_list signatures + P41 guardrail doc)
- Codebase: `lib/cairnloop/web/conversation_live.ex:839-1112` (card assign block + template, existing `<details>` locations)
- Codebase: `test/cairnloop/web/conversation_live_test.exs:1622-1702` (headless `render_component` card-test idiom, `tool_proposal_fixture/1`)
- Codebase: `test/cairnloop/web/components_test.exs:258-314` (existing `cl_disclosure` static-open unit tests)
- `deps/phoenix_live_view/lib/phoenix_live_view/js.ex:792-828` (`set_attribute`/`remove_attribute` with `to:` selector; the input-value caveat at :799)
- `mix.lock` (phoenix_live_view 1.1.30; lazy_html parser)
- `examples/cairnloop_example/assets/js/app.js:24-32` (colocated-hooks consumption namespace)
- CONTEXT.md (D-01..D-09) + UI-SPEC.md (interaction contract)

### Secondary (MEDIUM confidence)
- [hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html) — confirms `set_attribute({"open",""})` pattern for `<details>` and that JS-applied DOM ops persist across server patches

## Metadata

**Confidence breakdown:**
- Validation architecture (the primary ask): **HIGH** — testable seams verified directly in the repo's existing tests (headless `render_component`, DB-free, primitive unit tests already present)
- Standard stack: **HIGH** — all deps verified in mix.lock; JS API verified in deps source
- Migration mechanics: **HIGH** — exact `<details>` locations + `cl_disclosure` signature read first-hand; the one real gotcha (`data-tier` passthrough) identified
- Library JS-shipping (colocated hook namespace): **MEDIUM** — mechanism verified; the product-scope call (ship-and-wire vs document-only) is A4/Open-Q1 for owner veto

**Research date:** 2026-06-04
**Valid until:** ~30 days (stable; LiveView 1.1 line, internal codebase)

## RESEARCH COMPLETE

**Phase:** 41 - Conversation Rail Progressive Disclosure (D2)
**Confidence:** HIGH

### Key Findings
- `governed_action_card/1` already renders **headlessly** via `render_component(Function.capture(...), proposal: fixture)` with plain `%ToolProposal{}` structs and **no Repo** — every server-side rail assertion this phase needs is provable in the fast DB-free suite; **no `# REPO-UNAVAILABLE` markers required**.
- The PubSub-survival criterion is **not literally server-observable** (open state is browser-native); the correct proxy is a **mechanism assertion** — `phx-update="ignore"` present + `open` static-only. `cl_disclosure/1`'s static-only-open unit tests already exist (`components_test.exs:258-314`).
- `cl_disclosure/1` has **no `:global` passthrough**, so `data-tier="2"` (needed for Expand-all scoping) won't reach the `<details>` — the planner must add `attr(:rest, :global)` (additive, seal-safe).
- Density is **client-only** (localStorage + colocated JS hook); host-owned-library namespace gotcha: the example app imports `phoenix-colocated/cairnloop_example`, not `phoenix-colocated/cairnloop`, so a library hook is inert until the consumer's `app.js` is wired. Accepted server-test floor = markup-presence + JS-command-shape; localStorage round-trip deferred (no E2E layer in repo).
- `JS.set_attribute({"open",""}, to: "[data-tier='2']")` / `remove_attribute` verified in deps (1.1.30) and docs; works because `open` is a reflected boolean attribute, and JS DOM ops persist across server patches.

### File Created
`.planning/phases/41-conversation-rail-progressive-disclosure-d2/41-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Validation Architecture | HIGH | Seams verified in existing repo tests; honest server/client boundary mapped |
| Standard Stack | HIGH | All deps in mix.lock; JS API verified in deps source + docs |
| Migration mechanics | HIGH | Exact `<details>` locations + primitive signature read first-hand; `data-tier` gotcha found |
| Library JS-shipping | MEDIUM | Mechanism verified; ship-vs-document scope call flagged for owner (A4 / Open-Q1) |

### Open Questions
1. Density hook: ship colocated + wire example app (recommended) vs document-only for adopters — owner-vetoable product-scope call.
2. Browser/E2E coverage for localStorage round-trip — recommended OUT of scope; markup-presence floor accepted.

### Ready for Planning
Research complete. The `## Validation Architecture` section is ready to seed VALIDATION.md.
