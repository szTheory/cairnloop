# Phase 44: Motion - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply restrained, brand-aligned motion (brand book §15) across the operator cockpit using
**`transform` + `opacity` only**, on exactly these surfaces:

1. **Hero count entrance** (Home cockpit `.cl-stat__count` / Fraunces hero count) — one-shot, <180ms
2. **Rail / drawer reveal** — 260ms (`--cl-dur-panel`, `--cl-ease-drawer`)
3. **Gate state-flip** — 180ms cross-fade tagged `.cl-motion-state` (`--cl-dur-ui`)
4. **List-item enter** — staggered, ≤5 items (`--cl-stagger` 50ms)
5. **Toast enter / exit** — exit faster than entrance (`--cl-dur-exit` 160ms)

And honoring `prefers-reduced-motion: reduce` **live** — movement removed, comprehension
cross-fades (gate state) kept.

**Not in scope (own phases / deferred):**
- **Route-line draw + marker-travel motif, source-card stack reveal, FLIP list reorder** — these
  are `phx-hook` + WAAPI motifs, deferred to **v2 as AMOTION-01 / AMOTION-02**. Phase 44 is
  CSS-only motion. Do NOT build JS-driven motion hooks here.
- Motion on **reply-send**, **keystrokes / ⌘K search open**, **count-tick value updates**, or any
  **layout property** (`width`/`height`/`top`/`left`/`max-height`) — these MUST produce no transition
  on their triggering elements (success criteria 1 & 3 are partly *negative* assertions).
- Seed enrichment / screenshot regen / verification sweep — Phase 45.

</domain>

<decisions>
## Implementation Decisions

### Mechanism (Claude's discretion — locked)
- **D-01: Pure CSS only.** Entrance/reveal via `@keyframes` + `animation` and CSS transitions on
  utility classes (e.g. `.cl-motion-enter`, `.cl-motion-state`, stagger classes). For the few
  one-shot mount entrances that need a JS trigger, use `phx-mounted={JS.transition(...)}` sparingly
  (LiveView built-in; already a repo pattern — see `search_modal_component.ex:65`). **No new JS
  hooks, no WAAPI** — those are the deferred v2 AMOTION items. Rationale: restrained, dependency-light,
  brand-token-gate-safe (motion CSS uses no hex — gate only scans hex, so criterion 4 is satisfied by
  construction), and reduced-motion is already handled globally under `.cl-app`.
- **D-02: All motion CSS lives under `.cl-app`** so the existing global `prefers-reduced-motion` block
  zeroes it automatically. Author the lib source in `priv/static/cairnloop.css` (canonical) and mirror
  to `examples/cairnloop_example/priv/static/assets/css/app.css` (the two already share the token block).

### Hero count entrance vs. count-tick no-motion (success criteria 1 + 3)
- **D-03: Hero count entrance = fade + ~4px translate-up, one-shot, <180ms.** **No count-up / number-roll
  tween** (would read as busy and collides with the "no motion on count ticks" rule). The count text node
  itself carries **no `transition-property`**, so live value updates (ticks) are instant. Because morphdom
  patches the text in place (element not re-inserted), the entrance animation does not replay on tick.

### List-item enter stagger (success criterion 1; MOTION-01 "≤5")
- **D-04: CSS `nth-child(-n+5)` stagger delays on `<li>`**, animation = `transform`+`opacity` only,
  `--cl-stagger` (50ms) step. Animation fires on **DOM insert** — morphdom does not replay it on
  attribute-only patches (bulk-select, filter, count change), so it is naturally restrained.
- **D-05: Stagger is INSERT-ONLY, not replay-on-navigation.** *(User decision.)* The staggered entrance
  plays on first paint and when a genuinely new row is inserted; navigating away and back to a screen does
  **NOT** re-stagger existing rows. Rationale: calmest / most "restrained"; motion always signals real
  change rather than mere arrival. **Caveat for planner:** LiveView re-mounts the LiveView on live
  navigation, so a naive CSS-only animation WOULD replay on return. Honoring insert-only needs a small
  guard (e.g. a mount-once flag / `phx-mounted` one-shot that is not re-armed on re-entry, or scoping the
  stagger class so returning rows are already "settled"). Scope the lightest mechanism that holds this
  invariant; do not over-engineer.

### Gate state-flip (success criterion 1)
- **D-06: Reuse the existing `.cl-motion-state` hook.** Gate pending→draft-only/blocked/allowed flips
  cross-fade at 180ms (`--cl-dur-ui`), `transition-property: opacity, color, background-color, border-color`.
  This is the one motion that is **meaning-bearing**, so it is the cross-fade preserved under reduced-motion
  (the global block already re-enables `.cl-motion-state` at 120ms). Never state-by-color-alone still applies
  (brand §7.5) — motion supplements, never replaces, the textual/iconic state label.

### Rail / drawer reveal (success criterion 1)
- **D-07: Reveal via `translateX` + `opacity`, 260ms `--cl-dur-panel` / `--cl-ease-drawer`.** No
  `width`/`max-height` transition. Rail structure was finalized in P41 — apply motion additively, do not
  restructure the rail.

### Toast enter / exit (success criterion 1)
- **D-08: Toast/flash enter = `transform`+`opacity`; exit faster (`--cl-dur-exit` 160ms).** Drive via
  `phx-mounted` / `phx-remove` `JS.transition(...)` on the flash container. **Research item for planner:**
  the lib LiveViews use standard `put_flash`, but a styled `cl-toast`/`cl-flash` treatment may not yet exist
  in the lib layer (flash markup may currently live only in the example app's `core_components.ex`). Decide
  whether the toast treatment ships as a lib component + lib CSS or stays example-app-local — favor the lib
  layer if a reusable surface is warranted, consistent with the Governance/component-elevation posture.

### Reduced motion (MOTION-02; success criterion 2)
- **D-09: Largely already implemented** — the global `@media (prefers-reduced-motion: reduce)` block and the
  `.cl-motion-state` cross-fade re-enable already exist (`priv/static/cairnloop.css:197-211`). Phase work is
  (a) ensuring every NEW entrance animation sits under `.cl-app` so it is zeroed, and (b) confirming the gate
  flip (the comprehension aid) is the only motion that survives. "Honored **live**" means the media query —
  no JS toggle needed.

### Claude's Discretion
- Exact keyframe definitions, easing per surface (within the existing `--cl-ease-*` token set), precise
  translate distances, class naming, and the lib-vs-example placement of the toast treatment are all
  Claude/planner calls. Stay within existing duration/ease tokens (§ "Motion" token block,
  `cairnloop.css:142-153`) — do not invent new duration values that contradict the brand book bands
  (<180ms UI state, 240–320ms panel reveal).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Motion spec (authoritative)
- `prompts/cairnloop_brand_book.md` §15 (Motion and interaction, lines ~1008–1031) — motion principles,
  approved motifs, **forbidden** motifs (no typing indicator, no robot-thinking, no sparkles, no infinite
  pulse, no confetti), duration bands (<180ms UI state; 240–320ms panel reveal).
- `prompts/cairnloop_brand_book.md` §16.2 — "Respect dark mode and reduced motion"; §7.5 — never
  state-by-color-alone (motion must not become the sole state signal either).

### Requirements / roadmap
- `.planning/REQUIREMENTS.md` — **MOTION-01**, **MOTION-02** (and the deferred **AMOTION-01/02** that mark
  WAAPI motifs as v2, confirming Phase 44 is CSS-only).
- `.planning/ROADMAP.md` §"Phase 44: Motion" (lines ~174–184) — the four success criteria, including the
  negative assertions (no transition on reply-send / ⌘K / count tick; no layout-property transitions).

### Existing motion infrastructure (read before adding anything)
- `priv/static/cairnloop.css:142-157` — motion token block (`--cl-dur-instant/micro/ui/panel/exit/route`,
  `--cl-ease-out/in-out/drawer/linear`, `--cl-stagger`). **Reuse these; do not add new duration values.**
- `priv/static/cairnloop.css:197-211` — global `prefers-reduced-motion` block + `.cl-motion-state`
  cross-fade re-enable. MOTION-02 is mostly satisfied here already.
- `priv/static/cairnloop.css:420-423, 769` — `.cl-stat__count` and the Fraunces hero count (entrance targets).

### Gate (criterion 4 — must not flag motion)
- `test/cairnloop/web/brand_token_gate_test.exs` — confirms the gate scans **hex only** (`#rrggbb`/`#rgb`,
  `var(--cl-…, #hex)` fallbacks, inline-style hex, helper hex strings). Motion CSS that uses no hex passes by
  construction. Keep all new motion declarations hex-free.

### Attach points (LiveViews)
- `lib/cairnloop/web/home_live.ex` (hero count `.cl-stat`), `lib/cairnloop/web/inbox_live.ex:206`
  (`<li class="cl-row cl-list-row">` list rows), `lib/cairnloop/web/components.ex:139-145` (`.cl-stat`),
  `lib/cairnloop/web/search_modal_component.ex:65` (existing `phx-mounted={JS.focus()}` pattern to mirror).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Motion token set** (`cairnloop.css:142-157`): full duration + easing + stagger vocabulary already
  defined. The phase is mostly *applying* these, not defining new ones.
- **`.cl-motion-state`** + global reduced-motion block (`cairnloop.css:197-211`): the gate cross-fade and
  reduced-motion handling already exist — D-06 and D-09 lean on them directly.
- **`phx-mounted={JS.transition(...)}` / `phx-mounted={JS.focus()}`** (`search_modal_component.ex:65`,
  example `core_components.ex:42`): the one-shot-mount pattern to reuse for hero count / toast, avoiding new hooks.

### Established Patterns
- **Two-file CSS mirror:** `priv/static/cairnloop.css` (lib canonical) ↔
  `examples/cairnloop_example/priv/static/assets/css/app.css` share the token block. New motion rules must
  land in both.
- **Brand-token gate is a Repo-free string scan** for hex — additive, hex-free CSS is gate-safe.
- **morphdom semantics** are the backbone of D-03/D-04/D-05: CSS `animation` on an element runs on DOM
  *insert*, not on attribute-only patches, which is exactly the "motion = real change only" posture.

### Integration Points
- Home cockpit hero count, inbox `<li>` rows, rail/drawer container, policy-gate state cells, and the
  flash/toast container are the five attach points. All sit under `.cl-app`.
- Flash rendering: lib LiveViews call `put_flash`; the styled toast surface placement (lib component vs
  example-app `core_components.ex`) is an open research item flagged in D-08.

</code_context>

<specifics>
## Specific Ideas

- **Insert-only stagger** (D-05) is the explicit owner preference: motion should signal *real change*, not
  mere navigation/arrival. Calm over flashy.
- No count-up / number-roll on the hero count (D-03) — restraint over spectacle, and it keeps the
  "no motion on count ticks" rule clean.
- Strict adherence to the brand book's **forbidden motifs** list (§15.3): no typing indicators, robot-thinking,
  sparkles, infinite pulse, or confetti anywhere in the cockpit.

</specifics>

<deferred>
## Deferred Ideas

- **Route-line draw + marker-travel motif** (retrieve→draft→policy→review) and **source-card stack reveal /
  FLIP list reorder** — `phx-hook` + WAAPI. Already tracked as **AMOTION-01 / AMOTION-02**, deferred to **v2**.
  Do not pull into Phase 44.
- Cockpit-wide density tuning — out of scope (noted in P41 context as a separate concern).

None beyond the already-tracked v2 AMOTION items — discussion stayed within phase scope.

</deferred>

---

*Phase: 44-Motion*
*Context gathered: 2026-06-04*
