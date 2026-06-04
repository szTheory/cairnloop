# Phase 41: Conversation Rail Progressive Disclosure (D2) - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 6 (4 src + 2 test) — plus 1 net-new JS hook surface (no library analog)
**Analogs found:** 5 / 6 (the JS colocated hook is net-new — no existing analog in the library; see "No Analog Found")

All analogs are **in-repo, same module/file** as the code being changed. This is a restructuring phase: every "new" capability already has a primitive (`cl_disclosure/1`, `cl_fact_list/1`, `Phoenix.LiveView.JS`, the `:global` passthrough idiom). The planner should COPY the local conventions, not invent.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/conversation_live.ex` (`governed_action_card/1` ~957-1112) | component (function-component template) | request-response (pure render of `%ToolProposal{}`) | self (current bespoke `<details>` at :1001/:1018/:1048 + trace `dl` :1056) → migrate to `cl_disclosure/1` calls already used in this file's sibling primitives | exact (in-place restructure) |
| `lib/cairnloop/web/components.ex` (`cl_disclosure/1` ~198) | component (primitive) | request-response | `cl_switch/1` (`components.ex:243-254`) — the canonical `attr(:rest, :global)` + `{@rest}` passthrough idiom in this exact file | exact (role + mechanism) |
| `priv/static/cairnloop.css` (~534, ~500) | config (stylesheet, BEM + `.cl-` utilities) | n/a (static) | `.evidence-rail` block (`:534`), `.cl-details` block (`:500-508`), `.cl-toolbar` row (`:460-464`) | exact |
| Rail density JS hook (`localStorage["cl:rail:density"]`) | hook (colocated LiveView 1.1 hook) | event-driven (client mount → read/write localStorage → set `data-density`) | **NONE in library** — see "No Analog Found"; consumer-wiring analog = `examples/cairnloop_example/assets/js/app.js:25,32` | net-new |
| `test/cairnloop/web/conversation_live_test.exs` (new `describe`) | test (headless component) | request-response | existing card tests `:1647-1702` + `tool_proposal_fixture/1` `:1622-1639` | exact |
| `test/cairnloop/web/components_test.exs` (extend `cl_disclosure` block) | test (primitive unit) | n/a | existing `cl_disclosure` static-open block `:258-314` | exact |

---

## Pattern Assignments

### `lib/cairnloop/web/components.ex` — `cl_disclosure/1` (`:rest`/`:global` passthrough)

**Analog:** `cl_switch/1` (`components.ex:243-254`) — same file, the canonical global-attr passthrough.

**The gotcha (RESEARCH Pitfall 1):** `cl_disclosure/1` as written (`components.ex:193-204`) declares only `:id`, `:open`, `:summary`, `:inner_block`. It has **no `:rest`**, so `data-tier="2"` passed by the card template is silently dropped and Expand-all's `[data-tier="2"]` selector matches nothing.

**Copy the `:global` idiom from `cl_switch/1` (`components.ex:243-249`):**
```elixir
attr(:rest, :global,
  include: ~w(phx-click phx-value-id phx-value-key disabled form name value)
)

def cl_switch(assigns) do
  ~H"""
  <button type="button" class="cl-switch" role="switch" aria-checked={to_string(@checked)} {@rest}>
```

**Apply to `cl_disclosure/1` (additive — seal-safe per CLAUDE.md "seal completed phases"):**
- Add `attr(:rest, :global)` AFTER the existing `attr(:open, ...)` (no `include:` needed unless a `phx-*` is ever spread onto the `<details>`; `data-tier`/`data-density` are plain data-* globals and pass by default).
- Spread `{@rest}` onto the `<details>` in the `~H` at `components.ex:200`:
```elixir
<details class="cl-details cl-disclosure" id={@id} phx-update="ignore" open={@open} {@rest}>
```
- This does NOT change any existing call site's render (no current caller passes extra attrs), satisfying the additive constraint (RESEARCH A3).

**Doc note:** the existing `@doc` already carries the P41 forward-compat guardrail (`components.ex:189-191`) — extend the `@doc` one line to mention `:rest` carries `data-tier`/`data-density` scoping hooks.

---

### `lib/cairnloop/web/conversation_live.ex` — `governed_action_card/1` template (`:957-1112`)

**Analog:** self. The four bespoke disclosures and the always-visible trace `dl` are migrated to the `cl_disclosure/1` + `cl_fact_list/1` primitives that already exist in the sibling `components.ex`.

**Assign-block extension (compute auto-open booleans — D-08).** The card is a plain-assign render (P14 D-02); presenter values are computed at `:839-955` then `assign`-ed (`:937-955`). Add the auto-open booleans in that same block, derived ONLY from already-computed snapshot state (`active_approval` `:850-866`, `block_reason` `:846`) — static, render-time-only (D-09):
```elixir
# computed from already-resolved active_approval / block_reason — NO new live assign
pending? = match?(%{status: :pending}, active_approval)
auto_open_inputs = pending? or proposal.status in [:scope_invalid, :policy_denied]
auto_open_policy = proposal.status == :policy_denied
```
Then `|> assign(:auto_open_inputs, auto_open_inputs) |> assign(:auto_open_policy, auto_open_policy)` appended to the existing `:937-955` pipe. (Planner: confirm whether the block-reason trigger keys off `proposal.status` vs the `block_reason` copy presence — `block_reason_copy/1` at `:846` already encodes the `scope_invalid`/`policy_denied` discrimination; reuse it rather than re-deriving.)

**Migration map (D-01/D-02/D-03) — replace bespoke `<details style=…>` with `cl_disclosure`:**

1. **Tier-2 "Inputs & scope"** — wrap the existing Inputs section (`:992-1005`) in a `cl_disclosure` carrying `data-tier="2"` + `open={@auto_open_inputs}`. The nested Tier-3 "Raw input snapshot" (`:1001-1004`) becomes a *nested* `cl_disclosure` (default closed). Pattern to emit (RESEARCH Pattern 1):
```elixir
<.cl_disclosure id={"ga-#{@proposal.id}-inputs"} open={@auto_open_inputs} data-tier="2">
  <:summary>Inputs &amp; scope</:summary>
  <%!-- humanized rows (existing :996-998 for-loop over @input_rows) --%>
  <.cl_disclosure id={"ga-#{@proposal.id}-inputs-raw"}>
    <:summary>Raw input snapshot</:summary>
    <pre class="governed-action-trace" style="white-space: pre-wrap;"><%= inspect(@proposal.input_snapshot, pretty: true) %></pre>
  </.cl_disclosure>
</.cl_disclosure>
```
   D-03: the nested Tier-3 inherits patch-safety from the parent's `phx-update="ignore"` — but note `cl_disclosure/1` ALWAYS emits its own `phx-update="ignore"` regardless, so nesting is safe either way.

2. **Tier-2 "History"** — wrap the History section (`:1008-1035`) in a `data-tier="2"` `cl_disclosure` (NO auto-open). The per-event "Details" expanders (`:1018-1028`) each become a nested `cl_disclosure id={"ga-#{@proposal.id}-evt-#{idx}"}` (default closed). Keep the empty-state `No history yet.` (`:1033`) inside the group body.

3. **Tier-2 "Policy explanation"** — wrap Policy section (`:1044-1053`) in `data-tier="2"` `cl_disclosure` with `open={@auto_open_policy}`. The "Raw policy snapshot" expander (`:1048-1051`) becomes a nested `cl_disclosure` (default closed, still guarded by `@proposal.policy_snapshot` truthiness at `:1047`).

4. **Tier-3 standalone "Identifiers & trace" (D-02)** — REPLACE the always-visible trace `<dl>` (`:1056-1063`) with a closed `cl_disclosure` (NO `data-tier` — Expand-all must not reach it, D-06) whose body uses `cl_fact_list/1` (the RESEARCH "Don't Hand-Roll" target). Trace values come from the already-assigned `@trace` (`:948`):
```elixir
<.cl_disclosure id={"ga-#{@proposal.id}-trace"}>
  <:summary>Identifiers &amp; trace</:summary>
  <.cl_fact_list facts={[
    %{label: "Proposal", value: "##{@trace.proposal_id}"},
    %{label: "Tool", value: @trace.tool_ref},
    %{label: "Version", value: @trace.tool_version},
    %{label: "Idempotency key", value: @trace.idempotency_key}
  ]} />
</.cl_disclosure>
```

**Tier-1 — DO NOT TOUCH (RAIL-01).** Eyebrow/headline (`:960-961`), status chip row (`:964-970`), meta row (`:973-980`), outlook (`:983-985`), block-reason (`:988-990`), and the entire pending footer (`:1068-1109`) MUST remain OUTSIDE every `<details>`. They are already top-level siblings inside `<.cl_card>`; the migration only wraps the *middle* sections. The Scope section (`:1037-1041`) — note CONTEXT names exactly three Tier-2 groups (Inputs & scope / History / Policy); fold the Scope summary (`@scope_summary`) INTO the "Inputs & scope" group body (the group name is "Inputs & **scope**"), do not create a fourth Tier-2 group.

**Rail control bar (new Tier-1-sibling UI, RAIL-03).** Add ABOVE the first governed-action card. The natural mount point is the `.evidence-rail` container (`conversation_live.ex:477`) or the `governed-actions-rail-header` (`:493-495`). Put `data-density` + the hook on the rail container; render Expand/Collapse via `Phoenix.LiveView.JS` (RESEARCH Pattern 2) using `cl_button variant="ghost" size="sm"` — `cl_button` already allows `phx-click` via its `:global` include (`components.ex:36`), so the `JS` command reaches it:
```elixir
<div class="cl-rail-controls">
  <.cl_button variant="ghost" size="sm"
    phx-click={JS.set_attribute({"open", ""}, to: "[data-tier='2']")}>Expand all</.cl_button>
  <.cl_button variant="ghost" size="sm"
    phx-click={JS.remove_attribute("open", to: "[data-tier='2']")}>Collapse all</.cl_button>
  <%!-- density toggle button: phx-hook mount point — see JS hook section --%>
</div>
```
Requires `import Phoenix.LiveView.JS` (or `alias`) at the top of `conversation_live.ex` if not already imported — planner verify; `Cairnloop.Web` likely already imports it via the LiveView `use`.

**Error handling / escaping (V5 carried):** raw snapshots stay behind `inspect(.., pretty: true)` in `<pre>` (string, auto-escaped) — NEVER `raw/1`. This is the existing D-22 pattern at `:1003/:1025/:1050`; preserve verbatim. `cl_fact_list/1` auto-escapes `{fact.value}` (`components.ex:212`).

---

### `priv/static/cairnloop.css` (~`:534`, ~`:500`, ~`:460`)

**Analog:** `.evidence-rail` (`:534`), `.cl-details` block (`:500-508`), `.cl-toolbar` row (`:460-464`).

**Density rules** — append near `.evidence-rail` (`:534`). UI-SPEC §"Density CSS Contract" gives exact values; emit token-with-fallback form (matches the whole file's `var(--token, #hex)` convention, e.g. `:554`):
```css
.evidence-rail[data-density="comfortable"] { gap: var(--cl-space-7, 24px); }
.evidence-rail[data-density="comfortable"] > .cl-card { padding: var(--cl-space-gutter, 16px); }
.evidence-rail[data-density="compact"] { gap: var(--cl-space-4, 12px); }
.evidence-rail[data-density="compact"] > .cl-card { padding: var(--cl-space-4, 12px); }
```
Note: an existing rule `.evidence-rail > .cl-card { padding: var(--cl-space-gutter, 16px); }` lives at `:554` and `.evidence-rail { ... gap: var(--cl-space-7,24px); }` at `:534` — the comfortable variant duplicates these (intentional: default with no attribute still works; the `[data-density]` selectors are higher-specificity overrides). Planner may keep both (no flash) or fold the base into `[data-density]` — UI-SPEC says default `comfortable` matches existing, so keeping both is the no-flash choice (UI-SPEC §192).

**`.cl-rail-controls` row** — copy the `.cl-toolbar` flex idiom (`:460-464`), right-aligned, gap `--cl-space-3`:
```css
.cl-rail-controls {
  display: flex; align-items: center; justify-content: flex-end;
  gap: var(--cl-space-3, 8px); flex-wrap: wrap; padding: var(--cl-space-3, 8px) 0;
}
```
**No new disclosure CSS** — `.cl-details > summary` marker-reset + scoped `dl/dt/dd` (`:500-508`) already styles every `cl_disclosure`. `.cl-fact-list` (`:739-746`) styles the trace group body. Touch targets: ghost `sm` buttons are 28px (`:323`); UI-SPEC §49 wants ≥44px tap target on controls — add `min-height: 44px` via padding on `.cl-rail-controls .cl-button` OR use `--cl-control-h-lg: 44px` (`:133`) if the planner prefers a dedicated control size.

---

### `test/cairnloop/web/conversation_live_test.exs` — new `describe` block

**Analog:** existing card-render tests `:1647-1702` + `tool_proposal_fixture/1` (`:1622-1639`).

**Copy the exact headless idiom (`:1654-1656`) — DB-free, `Function.capture` runtime dispatch:**
```elixir
proposal = tool_proposal_fixture(%{status: :proposed})
card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
html = render_component(card_fn, proposal: proposal)
assert html =~ "Proposed"
```

**Fixture extension for auto-expand (D-08):** `tool_proposal_fixture/1` (`:1622`) merges arbitrary overrides via `Map.merge` (`:1638`). For the pending case, override `:approval` (or `:status`) — confirm the `%Cairnloop.Governance.Approval{}` field shape (`status: :pending`); RESEARCH A1 flags this as the one field-name risk. The base fixture has no `:approval` key, so add one in the override map.

**New tests to add (per RESEARCH Wave 0 §460, all headless):**
- RAIL-01: pending footer + quartet render OUTSIDE any `<details>` (assert `"Approval required"` present; structural sibling — RESEARCH `:328-341`).
- RAIL-02: 3 Tier-2 `cl_disclosure` present with `data-tier="2"` + correct summaries; Trace group present, default-closed, NOT `data-tier`.
- RAIL-02 mechanism: `<details` count == `phx-update="ignore"` count (RESEARCH `:346-354`).
- D-08 positive: pending/blocked fixture → inputs group emits static `open`; `policy_denied` → policy group also `open` (RESEARCH `:294-303`).
- D-08 negative: non-pending non-blocked → no Tier-2 emits `open` (RESEARCH `:305-311`).
- D-09 render-purity: `File.read!` source grep — `refute src =~ ~r/handle_event.*open/s` (RESEARCH `:314-325`).
- RAIL-03 JS shape: rendered `phx-click` carries `set_attribute`/`remove_attribute` scoped to `[data-tier="2"]`; density default `data-density="comfortable"` + control markup present.

Use `use ExUnit.Case, async: true` idiom already in the file.

---

### `test/cairnloop/web/components_test.exs` — extend `cl_disclosure` block (`:258-314`)

**Analog:** the existing `cl_disclosure` static-open tests (`:260-313`).

**Copy the `rendered_to_string(~H...)` primitive idiom (`:263-269`):**
```elixir
assigns = %{}
html =
  rendered_to_string(~H"""
  <.cl_disclosure id="inputs-scope" open={true} data-tier="2">
    <:summary>Inputs &amp; scope</:summary>
    <p>body content</p>
  </.cl_disclosure>
  """)
assert html =~ ~s(data-tier="2")   # NEW: proves :rest passthrough reaches <details>
```
The existing positive (`:260`, open→`open` attr) and negative (`:283`, open=false→no `open`) tests are the criterion-4 "no server assign controls open" proof — they ALREADY EXIST; the only addition is one test asserting `data-tier="2"` survives the new `:global` passthrough (RESEARCH Pitfall 1 / §461).

---

## Shared Patterns

### `:global` attribute passthrough
**Source:** `cl_switch/1` (`components.ex:243-249`), also `cl_button/1` (`:35-37`), `cl_card/1` (`:52`).
**Apply to:** `cl_disclosure/1` (add `attr(:rest, :global)` + `{@rest}` on `<details>`).
```elixir
attr(:rest, :global, include: ~w(phx-click phx-value-id phx-value-key disabled form name value))
# ... <button ... {@rest}>
```

### Patch-safe native disclosure (`cl_disclosure/1`)
**Source:** `components.ex:198-204`.
**Apply to:** all 4 rail groups (3 Tier-2 + Trace) AND the 3 nested Tier-3 raw expanders.
```elixir
<details class="cl-details cl-disclosure" id={@id} phx-update="ignore" open={@open}>
  <summary class="cl-details__summary">{render_slot(@summary)}</summary>
  {render_slot(@inner_block)}
</details>
```
`phx-update="ignore"` is emitted unconditionally → every disclosure survives PubSub re-render. `open` is the static boolean only.

### Client-side DOM ops via `Phoenix.LiveView.JS` (no server event)
**Source:** RESEARCH Pattern 2; verified `deps/phoenix_live_view/lib/phoenix_live_view/js.ex:792-828`.
**Apply to:** Expand-all / Collapse-all buttons. NO `handle_event` for open-state (D2/D-09 invariant).
```elixir
phx-click={JS.set_attribute({"open", ""}, to: "[data-tier='2']")}
phx-click={JS.remove_attribute("open", to: "[data-tier='2']")}
```

### Token-with-fallback CSS (never inline hex)
**Source:** whole file, e.g. `cairnloop.css:554`, `:534`.
**Apply to:** all new density + `.cl-rail-controls` rules.
```css
padding: var(--cl-space-4, 12px);   /* token first, hex fallback only */
```

### D-22 masking choke point (raw snapshots behind expanders, never `raw/1`)
**Source:** `conversation_live.ex:1003, 1025, 1050` (`inspect(.., pretty: true)` in `<pre>`).
**Apply to:** every Tier-3 raw snapshot group body. Preserve verbatim; nesting inside a `cl_disclosure` strengthens, never weakens, the choke point.

### Headless `render_component` card test
**Source:** `conversation_live_test.exs:1654-1656` + `tool_proposal_fixture/1` (`:1622`).
**Apply to:** every new Phase-41 rail test. DB-free; no `# REPO-UNAVAILABLE` markers needed (RESEARCH §423).
```elixir
card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
html = render_component(card_fn, proposal: tool_proposal_fixture(%{...}))
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Rail density JS hook (`cl:rail:density` → `data-density`) | hook (LiveView 1.1 `Phoenix.LiveView.ColocatedHook`) | event-driven (mount) | **NO colocated hook / `phx-hook` / `assets/` JS exists anywhere in the library.** Verified: `grep -rn "ColocatedHook\|phx-hook" lib/` returns nothing; the library has no `assets/` dir (only `examples/cairnloop_example/assets/`). This is **net-new** — the planner builds the first colocated hook in the repo. |

**Net-new guidance for the planner (from RESEARCH Pattern 3 + Pitfall 2 — HIGH-impact, verified):**

1. **Definition (library side):** ship a `<script :type={Phoenix.LiveView.ColocatedHook} name=".RailDensity">` block colocated next to `governed_action_card/1` (or in `components.ex`). The hook's `mounted()` reads `localStorage["cl:rail:density"]` (default `"comfortable"`) and sets `data-density` on the rail container; a toggle handler writes the new value. CSS attribute selectors (already specced) do the styling with no flash.

2. **Namespace gotcha (the reason there's no analog to copy wiring from):** the library app is `:cairnloop` (`mix.exs:6`), so a colocated hook lands in `phoenix-colocated/cairnloop`. But the example app's `app.js` imports ONLY `phoenix-colocated/cairnloop_example` (`examples/cairnloop_example/assets/js/app.js:25`) and merges only that into `LiveSocket` `hooks:` (`:32`). A library hook will compile but **silently never load** until the consumer adds the library-namespace import.

3. **Consumer-wiring analog (the ONLY existing pattern to copy):** `examples/cairnloop_example/assets/js/app.js:25,32`:
```js
import {hooks as colocatedHooks} from "phoenix-colocated/cairnloop_example"
// ...
hooks: {...colocatedHooks},
```
   The planner must ADD a sibling import + merge:
```js
import {hooks as libHooks} from "phoenix-colocated/cairnloop"
// ...
hooks: {...colocatedHooks, ...libHooks},
```

4. **Decision (RESEARCH default, per CLAUDE.md shift-left + adopter-first):** ship the colocated hook AND wire `examples/cairnloop_example/assets/js/app.js` AND document the import for adopters — the only option yielding a demonstrable "real ship." Owner-vetoable toward document-only (RESEARCH Open-Q1 / A4 = MEDIUM-risk product-scope call). Flag in plan summary.

5. **Test floor:** the hook's localStorage round-trip + real `open` toggle are **client-only / out of server-test scope** (no browser driver in `mix.lock`). Server-testable floor = `data-density="comfortable"` default attribute + control markup + (if shipped) the colocated `<script>` block present in rendered HTML. localStorage round-trip is deferred E2E.

---

## Metadata

**Analog search scope:** `lib/cairnloop/web/` (components.ex, conversation_live.ex), `priv/static/cairnloop.css`, `test/cairnloop/web/`, `examples/cairnloop_example/assets/js/`, `mix.exs`.
**Files scanned:** 6 in-repo source/test files read first-hand + 2 grep sweeps (colocated-hook existence, example app.js wiring).
**Key in-repo analog confirmations:**
- `cl_switch/1` (`components.ex:243-254`) — `:global` passthrough idiom for the `cl_disclosure` `:rest` addition.
- `cl_disclosure/1` (`components.ex:198-204`) — the disclosure primitive (no `:rest` today — the gotcha).
- `tool_proposal_fixture/1` (`conversation_live_test.exs:1622`) + card tests (`:1647-1702`) — headless DB-free render idiom.
- `examples/cairnloop_example/assets/js/app.js:25,32` — the ONLY consumer hook-wiring pattern; library has zero colocated hooks (net-new).
**Pattern extraction date:** 2026-06-04
