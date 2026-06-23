---
phase: 38-shared-page-shell-migration
reviewed: 2026-06-04T02:25:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/cairnloop/web/audit_log_live.ex
  - lib/cairnloop/web/breadcrumb_presenter.ex
  - lib/cairnloop/web/home_live.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/web/knowledge_base_live/editor.ex
  - lib/cairnloop/web/knowledge_base_live/gaps.ex
  - lib/cairnloop/web/knowledge_base_live/index.ex
  - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
  - lib/cairnloop/web/settings_live.ex
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 38: Code Review Report

**Reviewed:** 2026-06-04T02:25:00Z
**Depth:** standard (Elixir / Phoenix LiveView per-file analysis)
**Files Reviewed:** 9 source files (+ 7 test files for coverage adequacy)
**Status:** issues_found (1 Warning, 3 Info — no Critical / blocking defects)

## Summary

Phase 38 is a render-layer-only migration: every operator screen now nests
`<.cl_page title="…" width="wide">` inside its existing `<.cl_shell>`, and a new pure
`Cairnloop.Web.BreadcrumbPresenter` builds origin-aware breadcrumb item lists for the KB editor
and suggestion_review. I traced the new presenter against its two call sites, verified the
breadcrumb contract (last crumb omits `:href`), checked the `live_component` sibling-placement
pitfall on Inbox/Settings, and confirmed no schema queries, raw-path labels, hardcoded hex, or
debug artifacts were introduced.

Verification performed during review:
- `mix compile --warnings-as-errors` → **exit 0** (warnings-clean mandate satisfied).
- `breadcrumb_presenter_test.exs` → 29 tests, 0 failures (pure, no Repo).
- All migrated-screen render tests (home, audit, settings, inbox, gaps, suggestion_review,
  knowledge_base_live) → green.
- `brand_token_gate_test.exs` → green (no hex regression).
- Full `mix test` → 888 tests, **2 failures, both confirmed pre-existing baseline** and NOT
  phase-38 regressions: (1) `OutboundWorkerTest` D-11 dedup-keys check; (2) `SettingsLiveTest:18`
  `mount/3 stores host_user_id`, which fails only in the full-suite run due to a global
  `Application.put_env` mock-provider leak from another test — it **passes in isolation**
  (`mix test test/cairnloop/web/settings_live_test.exs:18` → 1 test, 0 failures), i.e. the known
  SettingsLive order-flake. Per instructions, neither is counted against this phase.

The presenter is genuinely pure and total: `editor_items/2` and `suggestions_items/1` both have a
catch-all clause, never call Repo, never emit markup, and never use the raw `return_to` path as a
crumb label. `@review_context` is always a map with a `return_to` key (path or `nil`), and the
presenter's non-binary clause covers the `nil` case, so no nil-deref path exists. The deeper
`task_title/1` helper feeding `suggestions_items/1` is also total (`"Untitled suggestion"`
fallback). The migration is faithful to D-02/D-04 (search modals kept inside `inner_block` per
Pitfall 4; `kb_nav`→`:subnav`; primary actions→`:actions`; filter bars left in body).

The findings below are low-severity quality observations, not defects in delivered behavior.

## Warnings

### WR-01: Origin-label derivation is silently coupled to producer path conventions

**File:** `lib/cairnloop/web/breadcrumb_presenter.ex:45-56`
**Issue:** `editor_items/2` decides the origin label purely from
`String.starts_with?(return_to, "/knowledge-base")` — "Suggestions" if it matches, else
"Conversation". Correctness depends entirely on the unwritten invariant that the *conversation*
producer (`conversation_live.ex`) only ever emits a bare `/{id}` return path. If a future producer
(or a route rename) ever set a conversation `return_to` that begins with `/knowledge-base`
(e.g. a KB-scoped conversation route), this editor crumb would silently mislabel a conversation
origin as "Suggestions" — exactly the failure mode RESEARCH Pitfall 1 warned about, just relocated
from `review_origin?` to the path prefix. This is not a live bug today (the producer is verified to
emit `/{id}`), but the coupling is implicit and untested, so a downstream route change would
regress it without any failing assertion.
**Fix:** Tighten the discriminator to the actual lane path and document the invariant, e.g.:
```elixir
defp origin_label(return_to) do
  # Lane handoffs always target the suggestions index; anything else is a conversation root.
  if String.starts_with?(return_to, "/knowledge-base/suggestions"),
    do: "Suggestions",
    else: "Conversation"
end
```
and add a presenter test asserting a non-lane `/knowledge-base/...` path (defensive) still labels as
"Conversation" — or, minimally, a `# INVARIANT:` comment recording that conversation `return_to`
must never start with `/knowledge-base`.

## Info

### IN-01: Inconsistent HEEx body indentation after the `cl_page` wrap

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:270-337`,
`lib/cairnloop/web/audit_log_live.ex:90-163`, `lib/cairnloop/web/knowledge_base_live/gaps.ex`,
`lib/cairnloop/web/knowledge_base_live/index.ex`, `lib/cairnloop/web/settings_live.ex`,
`lib/cairnloop/web/inbox_live.ex`
**Issue:** The body markup was wrapped in `<.cl_page>` without re-indenting the moved children
(e.g. editor `<.cl_banner>` at `:270` and the `<.cl_card>` at `:324` sit at the old outer indent
level inside the new `cl_page` nesting). HEEx ignores this, the screenshots are unaffected, and
`mix format` does not reflow HEEx attribute bodies — but the inconsistent indent makes the slot
boundary harder to read and future diffs noisier.
**Fix:** Re-indent the moved body blocks one level under `<.cl_page>` in a follow-up formatting-only
pass (no behavior change). Low priority; purely readability.

### IN-02: Pre-existing `Phoenix.HTML.raw/1` on preview HTML (not introduced by P38, flagged for tracking)

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:320`
**Issue:** `{Phoenix.HTML.raw(@preview_html)}` renders un-escaped HTML into the page. This predates
phase 38 (it was only re-indented under `cl_page`, not added), so it is **not a phase-38 finding** —
but it is the one un-escaped sink in the files under review and is worth tracking. Its safety
depends on `@preview_html` being produced by a trusted Markdown renderer over operator-authored
draft content; if that renderer does not sanitize embedded raw HTML, stored markup could execute in
the operator's session.
**Fix:** Out of scope for P38 (sealed body, D-05 "no rewrites"). Track separately: confirm the
markdown→HTML path sanitizes raw HTML, or wrap the preview render in an explicit sanitizer. Do not
change it in this phase.

### IN-03: Editor breadcrumb test name vs. payload could mislead future readers

**File:** `test/cairnloop/web/knowledge_base_live_test.exs:789-844`
**Issue:** The two origin-aware editor tests are correct (the `/42` test asserts "Conversation" +
`navigate="/42"`; the lane test asserts "Suggestions"), but the conversation test signs the handoff
with `return_to: "/42"` AND also passes a redundant top-level `"return_to" => "/42"` param that the
editor never reads (only the signed token's `return_to` is honored via
`verified_return_to_from_token/1`). The redundant param is harmless but could mislead a future
reader into thinking the unsigned param is load-bearing (it is not — that would be the open-redirect
hole the verified-token design exists to prevent).
**Fix:** Drop the redundant `"return_to"` map key from the mount params in both tests, leaving only
the signed `"handoff"` token, so the test documents the actual (verified-token-only) input contract.
Test-only; no production impact.

---

_Reviewed: 2026-06-04T02:25:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
