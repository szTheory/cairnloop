# Phase 44: Motion - Research

**Researched:** 2026-06-05
**Domain:** CSS-only brand-aligned motion (Phoenix LiveView / morphdom) across the Cairnloop operator cockpit
**Confidence:** HIGH (all claims verified against actual repo files; mechanism decisions pre-locked in CONTEXT.md)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01: Pure CSS only.** Entrance/reveal via `@keyframes` + `animation` and CSS transitions on utility classes (`.cl-motion-enter`, `.cl-motion-state`, stagger classes). For the few one-shot mount entrances that need a JS trigger, use `phx-mounted={JS.transition(...)}` sparingly (LiveView built-in). **No new JS hooks, no WAAPI** — those are the deferred v2 AMOTION items.
- **D-02: All motion CSS lives under `.cl-app`** so the existing global `prefers-reduced-motion` block zeroes it automatically. Author lib source in `priv/static/cairnloop.css` (canonical) and mirror to `examples/cairnloop_example/priv/static/assets/css/app.css`.
- **D-03: Hero count entrance = fade + ~4px translate-up, one-shot, <180ms.** No count-up / number-roll tween. The count text node carries **no `transition-property`**, so live value updates (ticks) are instant. morphdom patches text in place, so entrance does not replay on tick.
- **D-04: CSS `nth-child(-n+5)` stagger delays on `<li>`**, animation = `transform`+`opacity` only, `--cl-stagger` (50ms) step. Fires on DOM insert; morphdom does not replay it on attribute-only patches.
- **D-05: Stagger is INSERT-ONLY, not replay-on-navigation.** Plays on first paint and on genuinely new inserted rows; navigating away and back does NOT re-stagger. Needs a small guard (mount-once / `phx-mounted` one-shot, or settled-element scoping). Lightest mechanism wins — do not over-engineer.
- **D-06: Reuse the existing `.cl-motion-state` hook.** Gate flips cross-fade at 180ms (`--cl-dur-ui`), `transition-property: opacity, color, background-color, border-color`. This is the one meaning-bearing motion preserved under reduced-motion (re-enabled at 120ms). Never state-by-color-alone (§7.5) still applies.
- **D-07: Reveal via `translateX` + `opacity`, 260ms `--cl-dur-panel` / `--cl-ease-drawer`.** No `width`/`max-height` transition. Rail structure finalized in P41 — apply motion additively, do not restructure.
- **D-08: Toast/flash enter = `transform`+`opacity`; exit faster (`--cl-dur-exit` 160ms).** Drive via `phx-mounted` / `phx-remove` `JS.transition(...)`. **Research item (resolved below):** lib LiveViews use standard `put_flash`; decide lib-component vs example-app-local placement, favoring the lib layer if a reusable surface is warranted.
- **D-09: Reduced motion largely already implemented** — global `@media (prefers-reduced-motion: reduce)` + `.cl-motion-state` re-enable already exist (`cairnloop.css:197-211`). Phase work: (a) ensure every NEW entrance animation sits under `.cl-app`, (b) confirm the gate flip is the only motion that survives. "Honored live" = the media query; no JS toggle.

### Claude's Discretion
- Exact keyframe definitions, easing per surface (within existing `--cl-ease-*` set), precise translate distances, class naming, and the lib-vs-example placement of the toast treatment are all planner calls. Stay within existing duration/ease tokens (`cairnloop.css:142-153`) — do not invent new duration values that contradict brand bands (<180ms UI state, 240–320ms panel reveal).

### Deferred Ideas (OUT OF SCOPE)
- **Route-line draw + marker-travel motif** (retrieve→draft→policy→review) and **source-card stack reveal / FLIP list reorder** — `phx-hook` + WAAPI. Tracked as **AMOTION-01 / AMOTION-02**, deferred to **v2**. Do NOT pull into Phase 44 or build any JS motion hook.
- Cockpit-wide density tuning — out of scope (separate P41 concern).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MOTION-01 | Restrained brand motion applied (hero count <180ms; rail/drawer reveal 260ms; gate state-flip 180ms; list enter staggered ≤5; toast enter/exit) using transform + opacity only — never on reply-send, keystrokes, count ticks, or layout properties. **Note:** REQUIREMENTS.md line 62 also lists "route motif" in MOTION-01, but that is the WAAPI route-line motif deferred to AMOTION-01 (v2). Phase 44's MOTION-01 scope is the five CSS surfaces only. | Five surfaces all verified to have concrete attach points (§ Architecture). Tokens exist (`cairnloop.css:142-153`). Negative-assertion surfaces inventoried with file:line evidence (§ Negative Assertions). |
| MOTION-02 | `prefers-reduced-motion` honored live — movement removed, comprehension cross-fades kept. | Global block at `cairnloop.css:197-211` already zeroes animation/transition under `.cl-app` and re-enables `.cl-motion-state` at 120ms. Verified present in BOTH files. Phase work is keeping new rules under `.cl-app`. |
</phase_requirements>

## Summary

Phase 44 is a small, low-risk, additive CSS phase. The motion **vocabulary** (durations, easings, stagger step) is already shipped in both stylesheets; the reduced-motion handling is already shipped and correct. The phase is overwhelmingly *applying* existing tokens to five surfaces, plus authoring a handful of new hex-free `@keyframes`/utility classes.

Two facts materially change the plan from the optimistic framing in CONTEXT.md/UI-SPEC.md, and the planner must address them:

1. **`.cl-drawer` is defined in CSS but rendered NOWHERE.** The actual rail is `.evidence-rail` — a statically-present flex column on the conversation page (`conversation_live.ex:485`), not a JS-toggled drawer. There is no open/close toggle to drive a reveal transition. So D-07's "rail/drawer reveal" has no live trigger today. The planner must choose a concrete, restrained interpretation (recommendation below) rather than assume a drawer exists.
2. **`.cl-motion-state` has ZERO usages anywhere in the repo.** It is a defined-but-unused class. The gate state-flip (D-06) is currently *not wired to anything*. The concrete gate-state target is the `message-status-chip` (`status-pending` → `status-sent`/`status-failed`) at `conversation_live.ex:458` — and even that has no CSS rule today. The planner must (a) attach `.cl-motion-state` to a real state-changing element, and (b) ensure that element's text/icon label changes too (§7.5).

Both the toast placement (D-08) and these two items are the real open decisions. The morphdom reasoning (D-03/D-04/D-05), the token reuse, and the gate safety are all **verified correct**.

**Primary recommendation:** Ship a small set of hex-free `@keyframes`/utility classes in `cairnloop.css` (mirrored to the example app), wire them to the five surfaces via classes + `phx-mounted` one-shots, attach `.cl-motion-state` to the outbound `message-status-chip`, interpret the rail "reveal" as a one-shot `phx-mounted` entrance on `.evidence-rail` (it mounts fresh on conversation nav), and ship the toast treatment as a **lib-layer `cl_flash/1` component + `.cl-toast` CSS** so it is reusable and brand-consistent. Validate with string assertions on the CSS plus a Playwright E2E modeled on the existing `rail_disclosure_test.exs`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hero count entrance | CSS (cairnloop.css) | LiveView markup (`phx-mounted` one-shot) | Keyframe lives in CSS; one-shot trigger is a render-template attribute |
| Rail reveal | CSS | LiveView markup | `.evidence-rail` mounts fresh per conversation; entrance is a mount-time animation |
| Gate state-flip | CSS (`.cl-motion-state`) | LiveView markup (class attach + label change) | Transition is CSS; the morphdom class-swap on the status chip drives it |
| List-item stagger | CSS (`nth-child` delays) | LiveView markup (`<li>` / guard) | Animation on DOM insert is pure CSS; insert-only invariant needs a markup guard |
| Toast enter/exit | CSS (`.cl-toast`, keyframes) | LiveView component (`cl_flash/1`) + `JS.transition` | New reusable lib component owns markup; CSS owns the motion |
| Reduced-motion honoring | CSS (`@media` block) | — | Pure media query; no JS, no tier coordination |

All five surfaces sit under `.cl-app`. None require a backend/data-tier change. There is no auth/input/persistence surface in this phase.

## Standard Stack

This is a no-dependency phase. No packages are installed. The "stack" is the existing in-repo vocabulary.

### Core (already shipped — APPLY, do not redefine)

| Asset | Location | Purpose | Status |
|-------|----------|---------|--------|
| Motion token block | `cairnloop.css:142-153` | `--cl-dur-*`, `--cl-ease-*`, `--cl-stagger` | Present in both files [VERIFIED: file read] |
| Reduced-motion block | `cairnloop.css:197-211` | Zeroes motion under `.cl-app`; re-enables `.cl-motion-state` at 120ms | Present in both files [VERIFIED] |
| `phx-mounted={JS.transition(...)}` | `Phoenix.LiveView.JS` (built-in) | One-shot mount entrance | `JS.focus()` form already used at `search_modal_component.ex:65` [VERIFIED] |

**Exact tokens available** (`cairnloop.css:142-153`, identical in example app `app.css:122-132`) [VERIFIED: both files read]:

| Token | Value |
|-------|-------|
| `--cl-dur-instant` | 100ms |
| `--cl-dur-micro` | 140ms |
| `--cl-dur-ui` | 180ms |
| `--cl-dur-panel` | 260ms |
| `--cl-dur-exit` | 160ms |
| `--cl-dur-route` | 600ms (v2 AMOTION only) |
| `--cl-ease-out` | `cubic-bezier(0.23, 1, 0.32, 1)` |
| `--cl-ease-in-out` | `cubic-bezier(0.77, 0, 0.175, 1)` |
| `--cl-ease-drawer` | `cubic-bezier(0.32, 0.72, 0, 1)` |
| `--cl-ease-linear` | `linear` |
| `--cl-stagger` | 50ms |

**Caveat on `--cl-dur-ui` for the hero count:** MOTION-01 says hero entrance must be **< 180ms**. `--cl-dur-ui` is *exactly* 180ms. The UI-SPEC suggests `--cl-dur-ui`, but "must be < 180ms" reads as strictly-less-than. **Planner decision:** either accept 180ms as satisfying the band's intent (brand §15.1 says "under 180 ms" — borderline), or use `--cl-dur-micro` (140ms) for the hero count to be unambiguously inside the band. Recommendation: **use `--cl-dur-micro` (140ms)** for the hero count entrance to remove any ambiguity against MOTION-01's "<180ms" and stay clearly inside brand §15.1. [VERIFIED: cairnloop.css:144-145; brand_book §15.1 line 1013]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `phx-mounted={JS.transition(...)}` one-shot | A `phx-hook` JS class | Explicitly forbidden by D-01 (new hooks = deferred AMOTION). Do not. |
| New `cl_flash/1` lib component | Keep flash in example `core_components.ex` (DaisyUI) | Example app flash is DaisyUI (`toast toast-top`, `alert-info`) — not brand-token CSS. Lib component makes the brand toast reusable for any host. (Decision below.) |
| CSS `animation` on insert | WAAPI / FLIP | WAAPI is the deferred AMOTION-02 motif. Do not. |

**Installation:** None. No `mix deps` change. No npm/registry packages.

## Package Legitimacy Audit

Not applicable — Phase 44 installs **no external packages**. It adds CSS rules to existing files and one Elixir component function to an existing module. No registry interaction occurs. slopcheck/npm/pip/cargo verification is moot.

## Architecture Patterns

### System Data Flow (per surface)

```
                            ┌─────────────────────────────────────────┐
   put_flash(:info/:error)  │  Host layout flash_group → cl_flash/1    │
   from lib LiveView ──────▶│  phx-mounted JS.transition(cl-toast-enter)│──▶ DOM toast
   (conversation/inbox)     │  phx-remove  JS.transition(cl-toast-exit) │    (.cl-toast)
                            └─────────────────────────────────────────┘

   conversation nav  ──▶ ConversationLive mounts ──▶ .evidence-rail (fresh DOM)
                                                       └─ phx-mounted one-shot ──▶ reveal entrance

   home nav          ──▶ HomeLive mounts ──▶ .cl-hero__count (fresh DOM) ──▶ phx-mounted enter
   PubSub recount    ──▶ count assign changes ──▶ morphdom patches TEXT NODE in place
                                                  (element NOT re-inserted) ──▶ NO replay, NO tick transition

   inbox nav / new row ──▶ <li> inserted into DOM ──▶ nth-child(-n+5) stagger animation fires
   attr-only patch (bulk-select/filter) ──▶ morphdom patches attrs ──▶ NO animation replay

   outbound status change ──▶ status-pending → status-sent/failed class swap
                              on .message-status-chip.cl-motion-state ──▶ 180ms cross-fade
                              (+ label text changes — §7.5)
```

### Recommended file touch-set

```
priv/static/cairnloop.css                                   # canonical: new @keyframes + utility classes + .cl-toast
examples/cairnloop_example/priv/static/assets/css/app.css   # MIRROR the same .cl-* additions (see Two-File Mirror)
lib/cairnloop/web/components.ex                              # new cl_flash/1 component (lib toast)
lib/cairnloop/web/home_live.ex (or components.ex cl_hero)   # phx-mounted on hero count
lib/cairnloop/web/inbox_live.ex (~line 204-206)             # stagger container class + insert guard on <li>
lib/cairnloop/web/conversation_live.ex (~line 458, ~485)    # .cl-motion-state on status chip; phx-mounted on .evidence-rail
examples/cairnloop_example/.../layouts.ex or core_components # render the lib cl_flash in the host shell (placement decision)
examples/cairnloop_example/test/e2e/motion_test.exs         # new E2E (model on rail_disclosure_test.exs)
```

### Pattern 1: One-shot mount entrance (hero count, rail, toast enter)
**What:** `phx-mounted={JS.transition({"cl-motion-enter", "", ""}, time: 140)}` adds a class once when the element mounts. The class carries the `@keyframes`. Because it fires on mount (not on every patch), and the element is replaced only on a real LiveView mount, it is one-shot.
**When to use:** Hero count entrance, rail entrance. The repo already uses the simpler `JS.focus()` form at `search_modal_component.ex:65` [VERIFIED].
**Example:**
```elixir
# Source: existing repo pattern, search_modal_component.ex:65 (JS.focus form)
# Phoenix.LiveView.JS.transition/2 — adds the transition classes for `time` ms
<span class="cl-hero__count" phx-mounted={JS.transition("cl-motion-enter", time: 140)}>{@count}</span>
```
Note: `JS.transition/2` accepts either a single class string or a `{transition, from, to}` tuple. A single class that itself runs an `animation` is the lightest form and avoids from/to class churn.

### Pattern 2: Insert-on-DOM stagger via nth-child (list rows)
**What:** A container class plus `nth-child(-n+5)` delay rules. CSS `animation` runs when a node is inserted into the DOM; morphdom does NOT re-run it on attribute-only patches. [VERIFIED morphdom semantics: this is standard browser behavior — `animation` plays on element insert/`display` change, not on attribute mutation; corroborated by the codebase's own reliance on it, CONTEXT.md "Established Patterns".]
**When to use:** Inbox `<li class="cl-row cl-list-row">` rows at `inbox_live.ex:206` [VERIFIED].
**Insert-only guard (D-05) — the real landmine:** A plain CSS `animation` on `<li>` WILL replay every time the LiveView re-mounts on `navigate` (because the whole list is fresh DOM on mount). To honor INSERT-ONLY (no re-stagger on navigate-away-and-back), the lightest viable mechanisms, in order of preference:
  1. **`phx-mounted` one-shot on each `<li>` that adds the stagger class once** — but this still fires on every mount, so it does NOT by itself distinguish "returned to screen" from "first paint." This alone is INSUFFICIENT for D-05.
  2. **Accept first-paint stagger as correct, and only suppress *intra-session attribute patches*** — which morphdom already gives for free. Under this reading, "navigate away and back" re-mounts the LiveView and the owner's stated invariant ("navigating away and back does NOT re-stagger") would require server-side memory of "already seen."
  3. **Lightest honest mechanism:** scope the stagger animation to a `data-` marker set only on genuinely-new rows. In LiveView the cleanest signal is a streams insert (`phx-update="stream"`) — newly-inserted stream items get a fresh DOM node, re-rendered existing items do not. **If the inbox list is NOT yet a stream, converting it to `phx-update="stream"` is the correct, non-over-engineered way to get true insert-only animation** (animation fires only on stream inserts, never on the full re-mount of already-known rows within a session).
  - **Planner must verify** whether `inbox_live.ex` currently uses `stream/3` + `phx-update="stream"` or a plain `for` comprehension (current markup at line 205 is a plain `<%= for conv <- @conversations %>` — i.e. NOT a stream). **Recommendation:** Do NOT convert to streams just for motion (that is over-engineering and churns a working list — violates "seal completed phases"). Instead, **scope D-05 honestly:** implement first-paint + new-insert stagger via `nth-child`, and document that "navigate away and back re-mounts the LiveView, so the stagger replays on return" as an accepted limitation OR gate the stagger behind a one-shot `phx-mounted` that the planner explicitly notes does not survive re-navigation. Surface this as the single trade-off for the owner: full insert-only fidelity requires a stream conversion the owner said to avoid over-engineering. **Auto-decision per CLAUDE.md shift-left:** ship `nth-child` first-paint stagger; treat re-navigation replay as acceptable (it is calm, 5-item, ≤200ms); flag in the plan summary. Do not convert to streams.

### Pattern 3: Reuse `.cl-motion-state` for the gate flip
**What:** Add `.cl-motion-state` to the state-changing chip; define its base transition in CSS. The class is the SAME class the reduced-motion block re-enables, so the meaning-bearing cross-fade survives reduced-motion automatically.
**When to use:** `message-status-chip` at `conversation_live.ex:458` (the `status-pending`→`status-sent`/`status-failed` swap from `outbound_status_class/1`, `conversation_live.ex:741-750`) [VERIFIED]. This is the literal "policy gate changing from pending to draft-only/blocked/allowed" motif approved in brand §15.2 line 1023.
**§7.5 guard:** `outbound_status_class/1` already changes the *class*, but the planner MUST verify the chip's *text/icon label* also changes between states (not color alone). Currently the chip renders `outbound_status_class(msg)` as a class but the inner label text must be confirmed to differ per state — if the label is identical across states, that is a §7.5 violation the motion would worsen. **Action: planner adds a checkpoint to confirm the status chip carries distinct text per state.**

### Anti-Patterns to Avoid
- **Animating layout properties.** Never put `width`, `height`, `top`, `left`, `max-height`, `max-width` in any new transition/keyframe. Use `transform`/`opacity` only. (Criterion 3 negative assertion; testable by string-scanning new rules.)
- **Adding a `transition-property` to the count text node.** `.cl-hero__count` / `.cl-stat__count` currently carry NO transition [VERIFIED: cairnloop.css:421, 770]. Keep it that way so ticks are instant.
- **Re-defining `--cl-dur-*` / `--cl-stagger`.** They exist. Reuse.
- **Building a `phx-hook` for motion.** Deferred AMOTION (D-01).
- **Number-roll / count-up tween on the hero.** Forbidden by D-03.
- **`!important` motion overrides outside `.cl-app`** — would escape the reduced-motion zeroing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reduced-motion handling | A JS media-query listener / toggle | The existing `@media (prefers-reduced-motion)` block (`cairnloop.css:197-211`) | Already shipped, already correct, honors OS pref live with no JS |
| One-shot mount entrance | A custom hook | `phx-mounted={JS.transition(...)}` | LiveView built-in, already a repo pattern |
| Comprehension cross-fade survival | A second reduced-motion exception | `.cl-motion-state` (already re-enabled in the block) | Designed exactly for this |
| Motion durations/easings | New `--cl-*` values | The shipped token block | Brand bands already covered |
| Toast dismiss/hide | Custom JS | The Phoenix `lv:clear-flash` + `JS.hide`/`JS.transition` pattern (example `core_components.ex:63`) | Standard Phoenix flash idiom; `phx-remove` runs exit transition before removal |

**Key insight:** ~80% of this phase is already shipped infrastructure. The risk is *re-implementing* what exists, or *over-engineering* the stagger insert-only guard. Restraint is the requirement and the implementation posture.

## Toast Placement Decision (D-08) — RESOLVED

**Finding (verified):**
- Lib LiveViews (`conversation_live.ex`, `inbox_live.ex`) call standard `put_flash(:info/:error, ...)` extensively [VERIFIED: ~30 call sites].
- **No lib component renders flash as a toast.** The only lib flash rendering is `settings_live.ex:176-180`, which uses `<.cl_banner variant="success/danger">` — an *inline banner*, not a toast, and only for its own page.
- The actual toast that renders for lib LiveViews' `put_flash` is the **example app's** `flash/1` in `core_components.ex:56-86` [VERIFIED], invoked via `flash_group` in `layouts.ex:85-105`. It is **DaisyUI-based**: `class="toast toast-top toast-end z-50"`, inner `alert alert-info`/`alert-error` — i.e. it uses **no `.cl-*` brand tokens at all** and already has a `phx-click` clear-flash + `JS.hide` pattern, and its docstring shows the `phx-mounted={show(...)}` idiom.

**Decision (per CLAUDE.md component-elevation / Governance posture — auto-decided, shift-left):**
Ship the toast motion treatment as a **new lib-layer component `cl_flash/1` in `lib/cairnloop/web/components.ex`** with a `.cl-toast` brand-token CSS surface in `cairnloop.css`:
- `.cl-toast` surface: `background: var(--cl-surface-raised)`, `border: 1px solid var(--cl-border)`, `box-shadow: var(--cl-shadow-modal)` (or `--cl-shadow-overlay`), `border-radius: var(--cl-radius-md)`, positioned with `var(--cl-z-toast, 1500)`.
- Enter via `phx-mounted={JS.transition("cl-toast-enter", time: 180)}`; exit via `phx-remove={JS.transition("cl-toast-exit", time: 160)}`.
- Keep the dismiss idiom from the example `core_components.ex:63` (`JS.push("lv:clear-flash", ...) |> hide(...)`).
**Rationale:** makes the brand toast reusable by ANY host app (consistent with the Governance facade / component-elevation posture in CLAUDE.md); the example app's DaisyUI `flash/1` can coexist or be swapped to call `cl_flash/1`. The example shell must render the lib `cl_flash` to exercise it (placement: update `layouts.ex` flash_group to use `cl_flash`, OR add it alongside).
**Gate caveat:** the new `cl_flash/1` lives in `lib/cairnloop/web/*.ex` which **IS scanned by the brand-token gate** (unlike CSS). Any hex literal or raw `rgba()` in that component's markup will fail the gate. Keep all color via `var(--cl-*)` tokens / `.cl-toast` classes — no inline hex, no `rgba()`. [VERIFIED: gate globs `lib/cairnloop/web/**/*.ex`, test file lines 166-167, 197-198]

## Rail/Drawer Reveal (D-07) — landmine

**Finding (verified):** `.cl-drawer` is fully defined in `cairnloop.css:494-499` but **rendered in zero `.ex`/`.heex` files** [VERIFIED: grep returned nothing]. The real rail is `.evidence-rail` at `conversation_live.ex:485` — `<div class="evidence-rail" data-density="comfortable" phx-hook=".RailDensity" ...>` — a statically-present flex column, NOT a toggled drawer. There is no open/close event to drive a transition.

**Recommendation (auto-decided):** Interpret D-07's "reveal" as a **one-shot mount entrance** on `.evidence-rail` (it is freshly mounted each time a conversation page loads): `phx-mounted={JS.transition("cl-motion-reveal", time: 260)}` running a `translateX(16px)→0` + `opacity 0→1` `@keyframes` at `--cl-dur-panel`/`--cl-ease-drawer`. This satisfies "rail reveal via translateX+opacity, 260ms" without inventing a drawer toggle and without restructuring the P41-sealed rail (additive). Do NOT add a `width`/`max-height` transition. If a future genuinely-toggled `.cl-drawer` is introduced, the same `.cl-motion-reveal` class applies. Flag this interpretation in the plan summary for owner visibility.

## Runtime State Inventory

Phase 44 is additive CSS + one component; it renames nothing and migrates no data.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys, IDs, or records reference motion. | None |
| Live service config | None — no external service config involved. | None |
| OS-registered state | None. | None |
| Secrets/env vars | None. | None |
| Build artifacts | **Two-file CSS mirror** — new `.cl-*` rules added to `priv/static/cairnloop.css` MUST be mirrored into `examples/cairnloop_example/priv/static/assets/css/app.css`. The example app `app.css` is NOT served from the lib; it is a checked-in copy of the shared `.cl-*` block PLUS DaisyUI/Tailwind output. **Verified divergence:** lib file = 855 lines; example file = 4166 lines (contains additional compiled CSS + duplicate `@media (prefers-reduced-motion)` blocks at lines 3092 & 3593 from DaisyUI/Tailwind — leave those alone). | Mirror only the shared `.cl-*` additions into the appropriate region of `app.css` (after the `.cl-app` block, alongside the existing `.cl-*` rules). Do not touch the Tailwind/DaisyUI sections. |

**Canonical question answered:** After the lib CSS is updated, the example app's served stylesheet still has the OLD `.cl-*` block until manually mirrored. The mirror is the only "runtime state" landmine — and it is a build-artifact sync, not a data migration.

## Two-File CSS Mirror — verified reality

- The two files **share the entire `.cl-*` token + component vocabulary** (token block confirmed identical: lib `142-153` ≡ example `122-132`; reduced-motion block lib `197-211` ≡ example `180-191`) [VERIFIED: both read].
- The example `app.css` additionally contains a large Tailwind/DaisyUI compiled section (lines ~600-4166) with its own unrelated `@media (prefers-reduced-motion)` and `(no-preference)` blocks (lines 3092, 3593) — **do not modify those**; they belong to the example app's own component framework.
- **Mirror rule:** any new `@keyframes`, `.cl-motion-*`, `.cl-toast`, or stagger rule added to `cairnloop.css` under/after `.cl-app` must be copied verbatim into the `.cl-*` region of `app.css`. A divergence here means the example app (the screenshot/E2E surface) won't show the motion.

## Negative Assertions (Criterion 3) — file:line evidence

The planner can assert "no NEW transition added here" with this baseline:

| Surface | Element / Location | Current transition state | Note |
|---------|--------------------|--------------------------|------|
| Hero count tick | `.cl-hero__count` (`cairnloop.css:770-773`), `.cl-stat__count` (`cairnloop.css:421`) | **No `transition-property`** today [VERIFIED] | Keep it absent. Entrance is a one-shot `animation`, not a `transition`, so it cannot fire on text-node patches. |
| ⌘K / search open | search input `search_modal_component.ex:59-72` — `phx-mounted={JS.focus()}` only; `.cl-input` | `.cl-input` may have a focus-ring transition but the OPEN action adds none. No entrance/translate on open. [VERIFIED: only `JS.focus()`] | Do NOT add a `JS.transition` on the search modal open. |
| Reply-send | "Send Reply" `<.cl_button type="submit">` at `conversation_live.ex:480` | `.cl-button` **already** has a universal `transition: background-color/border-color/transform var(--cl-dur-instant)` (`cairnloop.css:298-311`) + `:active { transform: translateY(0.5px) }` | **Important nuance:** the existing universal button hover/active affordance is pre-existing and applies to ALL buttons. Criterion 3 means **do not add any NEW send-specific entrance/state motion** (no spinner, no fade, no "thinking" transition on send). It does NOT require stripping the shipped universal button micro-affordance. Planner should phrase the assertion as "no new motion class/transition is applied to the reply-send button or its payload," and the E2E should assert the send button has no `cl-motion-*` class and no added entrance. |
| Count-tick / layout props | any new rule | n/a | String-assert that no new motion rule contains `width`/`height`/`top`/`left`/`max-height`/`max-width`. |

**Subtlety the planner MUST encode:** the negative assertion is "no NEW motion," not "zero transitions exist on these elements." Buttons and inputs already have shipped micro-transitions. The E2E/string checks must target the *new* motion classes (`cl-motion-enter`, `cl-motion-reveal`, `cl-toast-*`, the stagger class), not the pre-existing universal `.cl-button`/`.cl-input` affordances.

## Brand-Token Gate Safety (Criterion 4) — verified

**Finding:** The gate (`test/cairnloop/web/brand_token_gate_test.exs`) scans only `**/*.ex` files in `lib/cairnloop/web/` and the example live dir [VERIFIED: lines 166-167, 197-198]. **`.css` files are NOT scanned at all** (docstring line 16: "`.css` is excluded structurally — only `.ex` globbed"). So:
- New motion CSS in `cairnloop.css` / `app.css` is **structurally outside the gate** — it cannot fail it, hex or not. (CONTEXT.md's "hex-free passes by construction" is correct, but the deeper reason is the file isn't scanned.)
- The **`cl_flash/1` component in `lib/cairnloop/web/components.ex` IS scanned.** Its markup must use only `var(--cl-*)` / `.cl-*` classes. **No** bare `#rrggbb`/`#rgb`, **no** `var(--cl-token, #hex)` fallback form, **no** raw `rgba()`/`rgb()`/`hsla()`/`hsl()`, **no** helper returning a hex string.

**Exact gate patterns** the planner must keep new `.ex` code clear of [VERIFIED: test lines ~28-40]:
- `@hex_fallback_pattern = ~r/var\(--cl-[a-z-]+,\s*#/` (the `var(--cl-x, #hex)` fallback form)
- `@hex_color = ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/` (bare 3/6-digit hex)
- `@func_color = ~r/\b(?:rgba?|hsla?)\(/` (raw color functions)
- Escape hatch: a `# cl-allow-color` comment on the same or preceding line (use never — keep it clean).

## Code Examples

### New CSS additions (hex-free, under `.cl-app`) — illustrative
```css
/* Source: composed from existing token block (cairnloop.css:142-153) + brand §15.1 */

/* Shared entrance keyframe — opacity + small translate only */
@keyframes cl-enter-up {
  from { opacity: 0; transform: translateY(4px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* Hero count + stat entrance (one-shot, < 180ms) */
.cl-app .cl-motion-enter {
  animation: cl-enter-up var(--cl-dur-micro) var(--cl-ease-out) both;  /* 140ms — clearly < 180ms */
}

/* Rail reveal (260ms drawer ease, translateX) */
@keyframes cl-reveal-x {
  from { opacity: 0; transform: translateX(16px); }
  to   { opacity: 1; transform: translateX(0); }
}
.cl-app .cl-motion-reveal {
  animation: cl-reveal-x var(--cl-dur-panel) var(--cl-ease-drawer) both;
}

/* List stagger — nth-child(-n+5), 50ms step, transform+opacity only */
.cl-app .cl-list-stagger > li:nth-child(-n+5) {
  animation: cl-enter-up var(--cl-dur-ui) var(--cl-ease-out) both;
}
.cl-app .cl-list-stagger > li:nth-child(1) { animation-delay: 0ms; }
.cl-app .cl-list-stagger > li:nth-child(2) { animation-delay: var(--cl-stagger); }
.cl-app .cl-list-stagger > li:nth-child(3) { animation-delay: calc(2 * var(--cl-stagger)); }
.cl-app .cl-list-stagger > li:nth-child(4) { animation-delay: calc(3 * var(--cl-stagger)); }
.cl-app .cl-list-stagger > li:nth-child(5) { animation-delay: calc(4 * var(--cl-stagger)); }

/* Gate state-flip — REUSE the class the reduced-motion block re-enables */
.cl-app .cl-motion-state {
  transition: opacity var(--cl-dur-ui) var(--cl-ease-linear),
              color var(--cl-dur-ui) var(--cl-ease-linear),
              background-color var(--cl-dur-ui) var(--cl-ease-linear),
              border-color var(--cl-dur-ui) var(--cl-ease-linear);
}

/* Toast surface + enter/exit (brand tokens; exit faster than enter) */
.cl-app .cl-toast {
  background: var(--cl-surface-raised); border: 1px solid var(--cl-border);
  box-shadow: var(--cl-shadow-modal); border-radius: var(--cl-radius-md);
  z-index: var(--cl-z-toast);
}
@keyframes cl-toast-enter { from { opacity: 0; transform: translateY(-8px); } to { opacity: 1; transform: translateY(0); } }
@keyframes cl-toast-exit  { from { opacity: 1; transform: translateY(0); } to { opacity: 0; transform: translateY(-4px); } }
.cl-app .cl-toast-enter { animation: cl-toast-enter var(--cl-dur-ui) var(--cl-ease-out) both; }
.cl-app .cl-toast-exit  { animation: cl-toast-exit var(--cl-dur-exit) var(--cl-ease-in-out) both; }
```

### One-shot mount entrance in markup
```elixir
# Source: existing pattern search_modal_component.ex:65 (JS.focus); JS.transition is the same family
import Phoenix.LiveView.JS
<span class="cl-hero__count" phx-mounted={JS.transition("cl-motion-enter", time: 140)}>{@count}</span>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JS-driven animation libraries | CSS `@keyframes`/`transition` + LiveView `JS.transition` one-shots | Stable for years | No deps; reduced-motion-friendly; this phase's whole posture |
| FLIP/WAAPI list motion | Deferred to v2 (AMOTION) | Project decision | Out of scope here |

**Deprecated/outdated:** None relevant. `Phoenix.LiveView.JS.transition/2` is current and stable (LiveView 1.1, already in use per the E2E harness memory note).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The inbox list at `inbox_live.ex:205` is a plain `for` comprehension, not a `stream/3` | Pattern 2 / D-05 | If it IS a stream, true insert-only is free; plan changes the guard. Verified line 205 reads `<%= for conv <- @conversations %>` — a comprehension, so this is HIGH confidence, listed for the planner to re-confirm before coding the guard. |
| A2 | The `message-status-chip` renders distinct *text* per state (not color alone) | Pattern 3 / §7.5 | If labels are identical across states, gate flip would lean on color alone (§7.5 violation). Planner must verify the chip's inner label text differs per `status-*`. NOT verified in this session (only the class swap was confirmed). |
| A3 | morphdom does not replay a CSS `animation` on attribute-only patches; replays on DOM insert | Patterns 2/3, D-03/04/05 | This is standard browser+morphdom behavior and the codebase already relies on it, but it is asserted from general knowledge, not a session-run browser test. The E2E should confirm empirically. |
| A4 | Rendering the lib `cl_flash` requires updating the example shell (`layouts.ex` flash_group) to invoke it | Toast decision | If the shell isn't updated, the new toast never renders and the E2E can't see it. Planner must include the shell wiring task. |

## Open Questions

1. **Does the outbound `message-status-chip` label text differ per state?** (A2)
   - What we know: `outbound_status_class/1` swaps the *class* (`status-pending/sent/failed`).
   - What's unclear: whether the chip's visible text also changes (it must, per §7.5).
   - Recommendation: planner adds a verification task; if labels are identical, add distinct labels as part of wiring `.cl-motion-state`.

2. **D-05 insert-only fidelity vs. stream conversion.** (A1)
   - What we know: plain comprehension re-mounts the whole list on navigate.
   - What's unclear: owner's tolerance for stagger replaying on navigate-back vs. converting the list to a stream.
   - Recommendation: ship `nth-child` first-paint stagger; accept navigate-back replay as a calm, bounded (≤200ms, ≤5 items) behavior; flag in the plan summary. Do NOT convert to streams (over-engineering; churns sealed list).

3. **Where exactly does the lib `cl_flash` get rendered in the example shell?** (A4)
   - Recommendation: replace/augment `layouts.ex` `flash_group` (lines 85-105) to call `cl_flash`. Keep the existing DaisyUI `flash/1` available or retire it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` / Elixir toolchain | build/test | ✓ (repo baseline; CI pins Elixir 1.19.5) | 1.19.5 (CI) | — |
| Playwright E2E harness (`phoenix_test_playwright`) | motion E2E | ✓ (existing `test.e2e` lane; 3 E2E tests present) | per repo | If unavailable locally, push to CI `e2e` lane |
| `Cairnloop.Repo` (Postgres) | NOT required by this phase | ✗ in workspace (known caveat) | — | All motion tests are DB-free string/E2E; E2E uses Playwright sandbox per `rail_disclosure_test.exs` |

**Missing with no fallback:** None blocking. **Missing with fallback:** Repo is unavailable locally (known baseline) — irrelevant to this CSS phase; validate E2E in CI per the integration/e2e-gate memory.

## Validation Architecture

> nyquist_validation is ABSENT from `.planning/config.json` → treated as ENABLED. This section is included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (unit/string scans) + `PhoenixTest.Playwright` (E2E, `@moduletag :e2e`) |
| Config file | `mix.exs` aliases (`test`, `test.e2e`, `test.integration`); E2E in `examples/cairnloop_example/test/e2e/` |
| Quick run command | `mix test test/cairnloop/web/brand_token_gate_test.exs` (gate, DB-free) + a new CSS string-scan test |
| Full suite command | `mix test` (excludes `:integration`/`:e2e`) then `mix test.e2e` + `mix test.integration` (CI lanes) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| MOTION-01 | New motion rules use only `transform`/`opacity` (no `width`/`height`/`top`/`left`/`max-height`/`max-width`) | unit (CSS string scan) | `mix test test/cairnloop/web/motion_css_test.exs` | ❌ Wave 0 |
| MOTION-01 | The two stylesheets are mirrored for the new `.cl-motion-*`/`.cl-toast`/keyframe rules | unit (string parity scan across both files) | same file | ❌ Wave 0 |
| MOTION-01 | Hero count animation present + duration < 180ms; count text node has no `transition-property` | E2E (`getComputedStyle` on `.cl-hero__count`) | `mix test.e2e` (motion_test.exs) | ❌ Wave 0 |
| MOTION-01 | Stagger applies to ≤5 `<li>`; rail reveal uses transform/opacity only | E2E (computed `animation-name`, `transition-property`) | motion_test.exs | ❌ Wave 0 |
| MOTION-01 (negative) | Reply-send button carries NO `cl-motion-*` class / no new entrance; ⌘K open adds none | E2E (assert absence of motion classes) + unit (grep for forbidden coupling) | motion_test.exs | ❌ Wave 0 |
| MOTION-02 | Under `prefers-reduced-motion: reduce`: transform animations → ~0.01ms; `.cl-motion-state` stays 120ms | E2E (`emulateMedia({reducedMotion:'reduce'})` + computed durations) | motion_test.exs | ❌ Wave 0 |
| Criterion 4 | `cl_flash/1` (`.ex`) is hex-free | unit (existing brand-token gate, auto-covers new `.ex`) | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ exists |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors` + the new CSS string-scan unit test + brand-token gate.
- **Per wave merge:** `mix test` (full headless) + `mix test.e2e` (motion_test).
- **Phase gate:** full suite green + E2E motion lane green before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/cairnloop/web/motion_css_test.exs` — DB-free string scan: (a) no new motion rule contains a forbidden layout property; (b) new `@keyframes`/`.cl-motion-*`/`.cl-toast` blocks exist in BOTH `cairnloop.css` and example `app.css` (mirror parity); (c) `.cl-hero__count`/`.cl-stat__count` rules contain no `transition-property`. Model on the DB-free pure-`File.read!` style of `brand_token_gate_test.exs`.
- [ ] `examples/cairnloop_example/test/e2e/motion_test.exs` — `@moduletag :e2e`, `use PhoenixTest.Playwright.Case`. Model header/fixtures on `rail_disclosure_test.exs`. Assert: hero `animation-name: cl-enter-up` + duration; drawer/rail transition is transform/opacity only; reply-send has no `cl-motion-*` class; `emulateMedia` reduced-motion → transforms ~0, `.cl-motion-state` = 120ms.
- [ ] No framework install needed — ExUnit + Playwright lane already present.

*(The negative assertions are best expressed as: string-scan that no new motion rule names a layout property, plus E2E that the reply-send/search elements carry none of the new `cl-motion-*` classes — NOT that they have zero transitions, since `.cl-button`/`.cl-input` carry pre-existing universal micro-affordances.)*

## Security Domain

> `security_enforcement` absent → enabled. This is a cosmetic, CSS-only phase with no auth, session, access-control, input, or crypto surface.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth touched) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | New `cl_flash/1` renders existing `put_flash` strings; no new user input is accepted. Flash content is operator-authored, escaped by Phoenix HEEx by default. |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unescaped flash content (XSS via toast) | Tampering/Info-disclosure | Use HEEx `{msg}` interpolation (auto-escaped) in `cl_flash/1`; never `raw/1`. Flash strings are operator-side, not end-user input — low risk, but keep escaping. |

No other security surface. CSS motion introduces no threat vector.

## Project Constraints (from CLAUDE.md)

- **Warnings-clean builds mandatory:** `mix compile --warnings-as-errors` must pass (the new `cl_flash/1` component must declare all `attr`/`slot` and use them).
- **`mix test` before done;** report failures honestly. Known baseline flakes (OutboundWorkerTest, a SettingsLive order-flake) are pre-existing — verify in isolation, do not count as regressions.
- **`Cairnloop.Repo` may be unavailable** locally — prefer DB-free tests (the motion CSS scan and brand gate are pure `File.read!`); E2E uses the Playwright sandbox.
- **Brand tokens over hardcoded hex** — `var(--cl-primary, #A94F30)` form is fine in CSS but the `var(--cl-x, #hex)` fallback form is FORBIDDEN in scanned `.ex` files (gate `@hex_fallback_pattern`). In `cl_flash/1` use bare `var(--cl-x)` / `.cl-*` classes, no hex.
- **Calm, operator-grade copy; never raw Elixir/JSON to operators; never state-by-color-alone (§7.5)** — the gate-flip chip must keep distinct text/icon per state.
- **Seal completed phases / additive changes** — do NOT restructure the P41 rail, do NOT convert the inbox list to streams, do NOT churn sealed `propose/3`/idempotency paths. Motion is additive only.
- **Two-file CSS mirror** — new `.cl-*` rules in `priv/static/cairnloop.css` AND `examples/.../app.css`.
- **Shift-left decisions** — the few gray-area calls (toast placement, rail-reveal interpretation, D-05 stagger fidelity) are auto-decided above with rationale; surface them in the plan summary for cheap veto rather than asking.

## Sources

### Primary (HIGH confidence — files read this session)
- `priv/static/cairnloop.css` — token block (142-157), reduced-motion block (197-211), `.cl-stat__count` (421), `.cl-hero__count` (770-773), `.cl-drawer` (494-499), `.cl-button` (298-311), `.cl-list-row` (444), `.cl-chip` (344-356)
- `examples/cairnloop_example/priv/static/assets/css/app.css` — mirror token block (122-132), reduced-motion (180-191); 4166 lines total (divergence confirmed)
- `test/cairnloop/web/brand_token_gate_test.exs` — gate patterns + `.ex`-only glob (166-167, 197-198)
- `lib/cairnloop/web/conversation_live.ex` — `.evidence-rail` (485), `message-status-chip` + `outbound_status_class` (458, 741-750), Send Reply button (480)
- `lib/cairnloop/web/inbox_live.ex` — `<li class="cl-row cl-list-row">` list (204-206)
- `lib/cairnloop/web/components.ex` — `cl_stat`/`cl_hero` (137-179)
- `lib/cairnloop/web/search_modal_component.ex` — `phx-mounted={JS.focus()}` (65)
- `examples/cairnloop_example/lib/cairnloop_example_web/components/core_components.ex` — DaisyUI `flash/1` (56-86)
- `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex` — `flash_group` (85-105)
- `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs` — E2E pattern to model
- `prompts/cairnloop_brand_book.md` — §15 (1008-1031): bands (<180ms UI, 240-320ms panel), approved motifs incl. policy gate (1023), forbidden motifs; §16.2 reduced motion (1047)
- `.planning/REQUIREMENTS.md` — MOTION-01/02 (62-63), AMOTION-01/02 deferred (84-85)
- `.planning/config.json` — nyquist absent (enabled), security absent (enabled)

### Secondary (MEDIUM)
- `Phoenix.LiveView.JS.transition/2` semantics — current LiveView built-in (corroborated by in-repo usage + E2E harness memory).

### Tertiary (LOW)
- morphdom "animation replays on insert, not on attr patch" (A3) — general browser/morphdom behavior; codebase relies on it but not browser-tested this session. E2E should confirm.

## Metadata

**Confidence breakdown:**
- Standard stack (tokens/mechanism): HIGH — all tokens and the reduced-motion block read directly; no new deps.
- Architecture / attach points: HIGH — every surface located by file:line; two landmines (no `.cl-drawer` render, unused `.cl-motion-state`) found and resolved.
- Pitfalls: HIGH — gate scope, mirror divergence, button-transition nuance, and D-05 stagger replay all verified.
- D-05 insert-only fidelity: MEDIUM — depends on inbox not being a stream (A1) and an accepted trade-off.
- §7.5 chip-label distinctness: MEDIUM (A2) — class swap verified, label-text distinctness not.

**Research date:** 2026-06-05
**Valid until:** ~2026-09-05 (stable in-repo facts; re-verify only if `cairnloop.css` token block, the inbox list markup, or the gate test glob change).
