---
phase: 37
slug: component-primitives
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-03
---

# Phase 37 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Register authored at plan time (all 5 PLANs carried `<threat_model>` blocks) →
> audited in **verify-mitigations** mode (no retroactive STRIDE scan).

**Audited:** 2026-06-03
**ASVS Level:** 1 (presentational UI phase — no auth/session/crypto/data-access/network surface)
**Auditor posture:** FORCE — each mitigation treated as absent until file:line evidence confirmed
**Result:** SECURED — 13/13 closed, 0 open, 0 blockers

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| caller assigns → rendered HTML | A caller LiveView (P38+/P41+, not this phase) supplies `title`/`subtitle`/`job`/`count`/summary/fact/`label`/meta text and slot content to the new function components. | Operator-facing display text (low sensitivity); the only control is output-encoding. |
| `:rest` global → emitted attrs | `cl_switch` forwards caller-supplied global attributes onto the rendered `<button>`. | HTML attributes; controlled by an explicit `include:` allowlist. |
| test → checked-in file | `cairnloop_css_test.exs` reads the project's own `priv/static/cairnloop.css`. | Static design-system text (no secrets/PII). |
| (none — static markup) | Plans 37-01 / 37-05 add static CSS and additive `<div>` a11y wrappers; no new untrusted input flow. | — |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-37-01 | Tampering (style drift) | `cairnloop.css` primitives | mitigate | Bare `var(--cl-*)` tokens only; brand-token gate + CSS-presence test enforce token purity | closed |
| T-37-02 | Information disclosure | CSS file-read in test | accept | Reads project's own checked-in CSS via hardcoded project-relative path; no secret/PII/external path | closed |
| T-37-03 | Tampering/Elevation (XSS) | `cl_page`, `cl_hero` caller text | mitigate | HEEx auto-escaped `{...}`; no caller input reaches `raw/1` | closed |
| T-37-04 | Tampering (style drift) | `cl_page`/`cl_hero` markup | mitigate | `.cl-*` classes only, no inline `style=`/hex; brand gate + per-test `refute #hex` | closed |
| T-37-05 | Tampering/Elevation (XSS) | `cl_disclosure`, `cl_fact_list` text | mitigate | HEEx auto-escaped `{...}`; no `raw/1` on caller input | closed |
| T-37-06 | Repudiation (stale UI) | `cl_disclosure` `phx-update="ignore"` subtree | accept | Frozen subtree by design (D-03); P41 forward-compat guardrail documented | closed |
| T-37-07 | Tampering (style drift) | `cl_disclosure`/`cl_fact_list` markup | mitigate | `.cl-*` classes only, no inline style/hex; gate + `refute #hex` | closed |
| T-37-08 | Tampering/Elevation (XSS) | `cl_source_card`/`cl_status_cell`/`cl_switch` text | mitigate | Auto-escaped `{...}`; `cl_icon` `raw/1` confined to fixed private icon-path allowlist; icon resolved via trusted `status_icon/1` map, never caller input | closed |
| T-37-09 | Spoofing/Tampering (attr injection) | `cl_switch` `:rest` global | mitigate | Explicit `include:` allowlist (`phx-click`/`phx-value-*`/`disabled`/form attrs); arbitrary attrs dropped | closed |
| T-37-10 | Information disclosure (state-by-color-alone, a11y) | status-bearing primitives | mitigate | Color + distinct-silhouette icon + visible text label (§7.5); `aria-checked` is a string; render-test verified | closed |
| T-37-11 | Tampering (regression) | 4 edited LiveView screens | mitigate | Only additive wrapper `<div>`; columns/rows/`:if`/screen logic untouched; warnings-as-errors + full test green | closed |
| T-37-12 | Information disclosure (a11y correctness) | `.cl-table-scroll` wrappers | mitigate | `role="region"` + `tabindex="0"` + call-site-specific `aria-label`; WR-01 omits empty focusable region | closed |
| T-37-SC | Tampering (supply chain) | npm/pip/cargo installs | accept | Zero external packages installed this phase | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Per-Threat Evidence

### T-37-01 — Style drift: CSS tokens only, zero hardcoded hex in primitive section

**Claim:** The Phase 37 primitive CSS block (lines 679–804 of cairnloop.css) emits only bare `var(--cl-*)` tokens — no hardcoded hex, no `var(--cl-x, #hex)` fallbacks.

**Verification:** A grep for `#[0-9a-fA-F]{3,6}` restricted to lines >= 679 of `priv/static/cairnloop.css` returned **no output**. The primitive section (`PRIMITIVE COMPONENTS` block, lines 679–804) is entirely token-driven.

**Supporting enforcement:** `brand_token_gate_test.exs` (line 30) scans all `.ex` files under `lib/cairnloop/web/` for `var(--cl-<token>, #<hex>)` patterns; this test is in the default `mix test` suite and passes. `cairnloop_css_test.exs` asserts `.cl-hero__count`, `.cl-fact-list`, `.cl-source-card--success`, `.cl-switch__track` all exist (structural markers confirming the section shipped).

**Status: CLOSED**

---

### T-37-02 — Info disclosure: CSS file-read in test

**Claim (accept):** The test reads only `priv/static/cairnloop.css`, which is the project's own checked-in static file containing no secrets or PII.

**Verification:** `cairnloop_css_test.exs` lines 12–13: `css_path = Path.join(File.cwd!(), "priv/static/cairnloop.css"); css = File.read!(css_path)`. The path is hardcoded, project-relative, and constructed from `File.cwd!()` — it cannot be influenced by caller input. No external path construction. The CSS file contains only design-system declarations.

**Status: CLOSED (accepted risk rationale holds)**

---

### T-37-03 — XSS: cl_page/cl_hero caller text

**Claim:** All caller strings in `cl_page` and `cl_hero` reach the template via HEEx auto-escaped `{...}`; no `Phoenix.HTML.raw/1` on caller input.

**Verification:**

- `cl_page` (components.ex lines 329–346): title at line 336 `{@title}`, subtitle at line 337 `{@subtitle}`, all slots via `render_slot/1`. No `raw/1` call in this function.
- `cl_hero` (components.ex lines 167–179): job at line 170 `{@job}`, count at line 171 `{@count}`, all slots via `render_slot/1`. No `raw/1` call.
- The only `Phoenix.HTML.raw/1` in the file is at **line 428**, inside `cl_icon/1`, applied to `icon_paths(@name)` — a private function with a fixed allowlist (see T-37-08).

**Status: CLOSED**

---

### T-37-04 — Style drift: cl_page/cl_hero markup

**Claim:** `cl_page` and `cl_hero` emit only `.cl-*` classes; no inline `style=` or hex. Enforced by brand gate and per-test `refute html =~ #hex`.

**Verification:**

- `cl_page` markup (lines 331–346): classes are `["cl-page", "cl-page--#{@width}"]`, `"cl-page__header"`, `"cl-row cl-row--between"`, `"cl-page__title"`, `"cl-page__subtitle"`, `"cl-page__subnav"`, `"cl-page__body"` — no `style=` attribute anywhere.
- `cl_hero` markup (lines 169–179): classes are `"cl-hero"`, `"cl-hero__job"`, `["cl-hero__count", ...]`, `"cl-hero__detail"`, `"cl-hero__cta"`, `"cl-button cl-button--primary"` — no `style=` attribute.
- `components_test.exs` lines 148–149, 163–164, 184–185, 197–199, 213–215, 226–228, 242–245, 253–256: every cl_page and cl_hero test includes `refute html =~ ~r/#[0-9a-fA-F]{3,6}/`.
- `brand_token_gate_test.exs` passes: no `var(--cl-*, #hex)` fallback in any `.ex` file.

**Status: CLOSED**

---

### T-37-05 — XSS: cl_disclosure summary, cl_fact_list label/value

**Claim:** All caller text in `cl_disclosure` and `cl_fact_list` goes through HEEx auto-escaped `{...}`; no `raw/1` on caller input.

**Verification:**

- `cl_disclosure` (lines 198–205): summary rendered as `{render_slot(@summary)}`, body as `{render_slot(@inner_block)}`. No `raw/1`.
- `cl_fact_list` (lines 217–227): label at `{fact.label}`, value at `{fact.value}`. Docstring at line 212 explicitly states "Facts are rendered via auto-escaped `{fact.label}` / `{fact.value}` — never `raw/1`." No `raw/1` in this function.
- The only `Phoenix.HTML.raw/1` in the entire file is line 428 (`cl_icon`), not reachable from caller-supplied data (see T-37-08).

**Status: CLOSED**

---

### T-37-06 — Repudiation (stale UI): cl_disclosure phx-update="ignore" subtree

**Claim (accept):** The `phx-update="ignore"` behavior on `cl_disclosure` is intentional design (D-03). The frozen subtree is documented. Forward-compat guardrail for P41 recorded.

**Verification:** `cl_disclosure` at line 200: `<details class="cl-details cl-disclosure" id={@id} phx-update="ignore" open={@open}>`. The `phx-update="ignore"` is present and intentional. Docstring at lines 182–195 documents the design decision and the P41 forward-compat guardrail ("Any live-updating content must be placed OUTSIDE the `<details>` element, not inside the `inner_block`"). The guardrail is also recorded in `37-03-SUMMARY.md` under "Forward-compat Guardrails Recorded for P41".

**Status: CLOSED (accepted risk rationale holds, forward-compat guardrail documented)**

---

### T-37-07 — Style drift: cl_disclosure/cl_fact_list markup

**Claim:** `cl_disclosure` and `cl_fact_list` emit only `.cl-*` classes; no inline style/hex.

**Verification:**

- `cl_disclosure` markup (lines 200–204): `class="cl-details cl-disclosure"`, `class="cl-details__summary"` — no `style=`, no hex.
- `cl_fact_list` markup (lines 219–226): `class="cl-fact-list"`, `class="cl-fact-list__row"`, `class="cl-fact-list__label"`, `class="cl-fact-list__value"` — no `style=`, no hex.
- Per-test `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` present in all three cl_disclosure tests (lines 280, 299, 313) and all three cl_fact_list tests (lines 332, 350, 362).

**Status: CLOSED**

---

### T-37-08 — XSS: cl_source_card/cl_status_cell/cl_switch caller text; cl_icon raw/1 allowlist

**Claim:** All caller text in these three components goes through auto-escaped `{...}`; `cl_icon`'s `raw/1` is on a FIXED private allowlist; `cl_source_card` resolves the icon via `status_icon/1` map, never from caller input.

**Verification:**

- **cl_source_card** (lines 274–290): title via `{render_slot(@title)}`, body via `{render_slot(@inner_block)}`, meta via `{render_slot(@meta)}`. Icon resolved at lines 276–278 via `assign_new(:resolved_icon, fn -> assigns[:icon] || status_icon(assigns.source_variant) end)` — the `icon` attr is an optional override but only feeds into `cl_icon` which then calls `icon_paths(@name)`, a private function; `source_variant` is an enum-declared attr (`values: ~w(success info neutral warning danger ai)`).
- **cl_status_cell** (lines 305–311): delegates entirely to `cl_chip` — no raw text interpolation; label is passed as an attr value.
- **cl_switch** (lines 247–253): label at `{@label}` (auto-escaped). No `raw/1`.
- **cl_icon `raw/1`** (line 428): `{Phoenix.HTML.raw(icon_paths(@name))}`. The `icon_paths/1` function is `defp` (private, lines 450–515) and has a hardcoded exhaustive match on named strings; the catch-all fallback at line 515 is `defp icon_paths(_unknown), do: icon_paths("dot")` — any unrecognized name resolves to the safe dot SVG path string. The paths are hardcoded SVG geometry strings with no dynamic interpolation from caller input. The `@name` attr flows from component calls, but the private function never embeds it into the SVG string — the name is only used as a match key. No caller string can reach `raw/1` output.

**Status: CLOSED**

---

### T-37-09 — Attr injection: cl_switch :rest include allowlist

**Claim:** `cl_switch` `:rest` uses an explicit `include:` allowlist, not a passthrough; arbitrary attributes are dropped by Phoenix.Component.

**Verification:** components.ex lines 243–245:
```
attr(:rest, :global,
  include: ~w(phx-click phx-value-id phx-value-key disabled form name value)
)
```
This is `include:` (allowlist mode), not the default passthrough behavior. Phoenix.Component with `include:` only forwards the listed attrs via `{@rest}`; all other attrs are silently dropped. The allowlist covers LiveView wiring (`phx-click`, `phx-value-id`, `phx-value-key`) and HTML form attrs (`disabled`, `form`, `name`, `value`). No arbitrary/unknown attrs can pass through.

**Status: CLOSED**

---

### T-37-10 — Info disclosure (state-by-color-alone a11y)

**Claim:** Every status-bearing primitive pairs color + distinct-silhouette icon + visible text label. `aria-checked` is a string. Verified by render tests.

**Verification:**

- `cl_chip` (lines 76–86): always renders `<.cl_icon name={@resolved_icon} class="cl-chip__icon" />` alongside `{@label}`. `status_icon/1` provides distinct silhouettes: check-circle (success), info (info circle), alert-triangle (warning), x-circle (danger), waypoint (ai), clock (neutral) — each geometrically distinct.
- `cl_banner` (lines 95–105): always renders `<.cl_icon .../>` plus slot content. Has `role="status"` at line 100.
- `cl_switch` (line 249): `aria-checked={to_string(@checked)}` — emits literal string `"true"` or `"false"`, not a boolean HTML attribute. `{@label}` always rendered. CSS uses `[aria-checked="true"]` attribute selector (cairnloop.css line 791), not color alone.
- `cl_source_card` resolves icon from `status_icon/1` map — icon always present in header.
- `components_test.exs`: cl_chip test (line 27) asserts `assert html =~ "<svg"` and `assert html =~ "Needs review"`. cl_switch tests assert `aria-checked="false"` and `aria-checked="true"` string form. cl_status_cell test (line 407) asserts both `"<svg"` and label text.

**Status: CLOSED**

---

### T-37-11 — Tampering (regression): 4 edited LiveView screens

**Claim:** Only an additive `<div>` wrapper was added — columns/rows/:if guards/screen logic untouched.

**Verification:** Read all four files in full.

- `audit_log_live.ex` line 129: wrapper `<div :if={@visible_events != []} class="cl-table-scroll" role="region" tabindex="0" aria-label="Audit log">` — the `:if` condition is on the wrapper div; the table and all existing `<th>/<td>` structure is unchanged.
- `knowledge_base_live/index.ex` line 78: identical pattern; table structure unchanged.
- `knowledge_base_live/suggestion_review.ex` line 220: identical pattern; table and row logic unchanged.
- `settings_live.ex` line 246: identical pattern; `cl-mb-7` preserved on `<table>` (line 247), not moved to wrapper.
- In all four files, the `:if` guard is on the wrapper div (checking the collection is non-empty), which means the empty-state path (`cl_empty` component) continues to render correctly — the empty focusable region is omitted when no rows (WR-01 fix confirmed by `:if={... != []}` on the wrapper).
- No column definitions, event handlers, `handle_event`, `mount`, or `handle_params` were modified.

**Status: CLOSED**

---

### T-37-12 — Info disclosure (a11y correctness): .cl-table-scroll wrappers

**Claim:** Each wrapper has `role="region"`, `tabindex="0"`, and a descriptive, call-site-specific `aria-label` (not generic). WR-01: empty focusable region omitted when no rows.

**Verification:** Grep of all 4 files confirmed:

| File | aria-label value | role | tabindex |
|------|-----------------|------|---------|
| audit_log_live.ex:129 | `"Audit log"` | `region` | `0` |
| knowledge_base_live/index.ex:78 | `"Knowledge base articles"` | `region` | `0` |
| knowledge_base_live/suggestion_review.ex:220 | `"Suggested KB edits"` | `region` | `0` |
| settings_live.ex:246 | `"Policies"` | `region` | `0` |

All four labels are data-domain specific (none is generic "table" or "data"). All four wrappers carry `:if={... != []}` guards — the focusable region is entirely omitted when the collection is empty (WR-01 fix confirmed). `.cl-table-scroll:focus-visible` in cairnloop.css lines 449–450 provides visible focus ring via `var(--cl-focus-ring)`.

**Status: CLOSED**

---

### T-37-SC — Supply chain: no npm/pip/cargo installs

**Claim (accept):** Zero external packages were installed in this phase. No supply-chain surface introduced.

**Verification:** `37-01-SUMMARY.md` through `37-05-SUMMARY.md` all list `tech_stack.added: []`. No `mix.exs`, `package.json`, or lockfile changes are present in the phase. All components use only `Phoenix.Component`, `Phoenix.HTML`, and HEEx — already in the existing dependency tree.

**Status: CLOSED (accepted risk rationale holds — no packages installed)**

---

## Unregistered Flags

The following `## Threat Flags` / `## Threat Surface Scan` entries appeared in phase SUMMARY files:

- **37-01-SUMMARY.md:** "No new threat surface introduced." — informational, maps to existing T-37-01 / T-37-02.
- **37-02-SUMMARY.md:** "No new security surface introduced. XSS mitigations T-37-03 and T-37-04 confirmed." — maps to T-37-03, T-37-04.
- **37-03-SUMMARY.md:** "T-37-05 (XSS), T-37-06 (Stale UI), T-37-07 (Style drift) — all confirmed." — maps to existing register entries.
- **37-04-SUMMARY.md:** "XSS mitigated via HEEx... T-37-08, T-37-09." — maps to existing register entries.
- **37-05-SUMMARY.md:** No threat flags section; plan is purely additive wrapper with no new surface.

**Unregistered flags: none.** All executor-surfaced flags map to registered threat IDs.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-37-01 | T-37-02 | Test reads project's own `priv/static/cairnloop.css` via hardcoded project-relative path. No external path construction; no secrets/PII in file. | gsd-security-auditor | 2026-06-03 |
| AR-37-02 | T-37-06 | `phx-update="ignore"` frozen subtree is intentional design for browser-owned disclosure state (D-03). Forward-compat guardrail documented in `cl_disclosure` docstring + 37-03-SUMMARY.md for P41 adopters. | gsd-security-auditor | 2026-06-03 |
| AR-37-03 | T-37-SC | Zero external packages installed in this phase. No supply-chain surface. | gsd-security-auditor | 2026-06-03 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-03 | 13 | 13 | 0 | gsd-security-auditor (verify-mitigations mode) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-03
