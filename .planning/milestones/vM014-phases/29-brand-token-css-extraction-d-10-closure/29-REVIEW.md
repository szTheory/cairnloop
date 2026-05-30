---
phase: 29-brand-token-css-extraction-d-10-closure
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - examples/cairnloop_example/assets/css/app.css
  - examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/web/search_modal_component.ex
  - test/cairnloop/web/brand_token_gate_test.exs
  - test/integration/approval_footer_live_test.exs
  - test/integration/bulk_recovery_live_test.exs
  - test/integration/tool_execution_outcome_live_test.exs
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-05-27
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 29 delivers the brand-token CSS extraction (D-10 closure), the widget chat LiveView (D-11–D-13), and integration tests for several governance surfaces. The CSS token layer in `app.css` is solid — all 15 primitives and semantic aliases are well-formed, and the gate test pattern is correct for what it checks.

Two blockers surface on code paths that exist today in production routes:

1. The production `Cairnloop.Retrieval` path in `SearchModalComponent.run_search/3` re-raises exceptions that propagate unhandled to the LiveComponent process — crashing it with a generic Phoenix overlay instead of rendering the graceful error-state UI.
2. `InboxLive.do_confirm_bulk_send/1` accesses `preview.template_id` after a `case` branch that handles `nil` preview for `ids` — but the `opts` list construction on the very next line (`preview.template_id`) crashes if `preview` is `nil`, reachable when the `confirm_bulk_send` event fires with `bulk_modal_open: false`.

Four warnings round out the findings: the BRAND-04 gate does not scan subdirectories, two hardcoded `color: white` values escape token enforcement, and the reject/defer form in the approval footer has no `phx-submit-loading` guard.

---

## Critical Issues

### CR-01: `run_search(Cairnloop.Retrieval, ...)` does not rescue exceptions; crashes the LiveComponent

**File:** `lib/cairnloop/web/search_modal_component.ex:471-476`

**Issue:** `Cairnloop.Retrieval.search/2` emits telemetry then calls `reraise error, __STACKTRACE__` when an adapter (Postgres, pgvector, HTTP embedder) throws (see `lib/cairnloop/retrieval.ex:27`). The first `run_search/3` clause, which pattern-matches on the production module `Cairnloop.Retrieval`, contains no `try/rescue`:

```elixir
defp run_search(Cairnloop.Retrieval, query, opts) do
  case Cairnloop.Retrieval.search(query, opts) do
    {:error, reason} -> {:error, reason}
    results -> {:ok, results}
  end
end
```

The second clause (used for stub/test modules) does have a `try/rescue`. This means the production path is unprotected: a DB timeout or network failure in the retrieval layer propagates uncaught, crashes the LiveComponent process, and renders the generic Phoenix error overlay instead of the intended `@error = true` search-state UI. The degraded search state is unreachable on production errors.

**Fix:**

```elixir
defp run_search(Cairnloop.Retrieval, query, opts) do
  try do
    case Cairnloop.Retrieval.search(query, opts) do
      {:error, reason} -> {:error, reason}
      results -> {:ok, results}
    end
  rescue
    error -> {:error, error}
  end
end
```

---

### CR-02: `do_confirm_bulk_send/1` crashes with `KeyError` when `bulk_preview` is `nil`

**File:** `lib/cairnloop/web/inbox_live.ex:466-494`

**Issue:** `do_confirm_bulk_send/1` is guarded by `confirm_bulk_send`'s `cond` block, but that block does NOT check whether `bulk_modal_open` is `true` or whether `bulk_preview` is non-nil. If a `confirm_bulk_send` event arrives while the modal is not open (crafted WebSocket frame, race between modal-close and confirm-click), execution falls through to `do_confirm_bulk_send` with `socket.assigns.bulk_preview == nil`.

The `case preview do` block at line 484 handles `nil` via the `_` fallback for `ids`, but line 493 accesses `preview.template_id` unconditionally:

```elixir
opts = [
  template_id: preview.template_id,   # KeyError when preview is nil
  rendered_body: preview.rendered_body,
  actor: actor
]
```

This crashes the LiveView process. The `bulk_refusal != nil` guard (line 453) only protects the refusal case where `bulk_preview` is `nil` AND the modal is open in refusal mode — it does not protect the case where the modal is not open at all.

**Fix:** Add a guard at the top of `confirm_bulk_send` (or the top of `do_confirm_bulk_send`) for a nil preview:

```elixir
def handle_event("confirm_bulk_send", _params, socket) do
  cond do
    is_nil(recovery_follow_up_template_id()) -> # ... existing
    socket.assigns.bulk_refusal != nil -> # ... existing
    is_nil(socket.assigns.bulk_preview) ->
      # Modal not open or already dismissed — silently no-op.
      {:noreply, socket}
    true ->
      do_confirm_bulk_send(socket)
  end
end
```

---

## Warnings

### WR-01: BRAND-04 gate test scans only top-level `lib/cairnloop/web/*.ex` — subdirectories are excluded

**File:** `test/cairnloop/web/brand_token_gate_test.exs:32-33`

**Issue:** The wildcard pattern `Path.join(@web_dir, "*.ex")` matches only flat files in the directory, not files in subdirectories. There are `.ex` files in `lib/cairnloop/web/knowledge_base_live/` and `lib/cairnloop/web/mcp/` that are outside the gate's coverage. Currently none of those files contain `var(--cl-X, #hex)` violations, but any future hex-fallback introduction there will silently pass the gate — defeating the D-10 enforcement guarantee.

**Fix:**

```elixir
# Use "**/*.ex" glob to cover subdirectories
files =
  Path.wildcard(Path.join(@web_dir, "**/*.ex")) ++
    Path.wildcard(Path.join(@example_live_dir, "**/*.ex"))
```

---

### WR-02: Two `color: white` instances bypass brand token enforcement and dark-mode adaptation

**File:** `lib/cairnloop/web/conversation_live.ex:992`, `lib/cairnloop/web/search_modal_component.ex:195`

**Issue:** Both files contain `color: white` as the text color on primary-background buttons. The project establishes `var(--cl-primary-text)` (aliased as `var(--cl-on-primary)`) specifically for on-primary text, and the dark-mode overrides in `app.css` set `--cl-primary-text: #18211F` (dark basalt, not white). Using hardcoded `white` means these buttons will have a light-on-light contrast failure in dark mode.

`inbox_live.ex` already correctly uses `var(--cl-on-primary)` for the same button pattern — these two are inconsistent with the established pattern.

- `conversation_live.ex:992`: Propose button in `tool_renderer`
- `search_modal_component.ex:195`: Open-result action button in the preview pane

**Fix:** Replace both:
```elixir
# conversation_live.ex:992
style="... background: var(--cl-primary); color: var(--cl-on-primary); ..."

# search_modal_component.ex:195
style="... background: var(--cl-primary); color: var(--cl-on-primary); ..."
```

---

### WR-03: Reject / Defer forms in `governed_action_card` have no `phx-submit-loading` guard — double-submit possible

**File:** `lib/cairnloop/web/conversation_live.ex:1393-1423`

**Issue:** The Reject and Defer `<form>` elements use `phx-submit="reject_action"` and `phx-submit="defer_action"` but have no `phx-submit-loading:opacity-50` or `phx-submit-loading:pointer-events-none` on their submit buttons. The Approve button (line 1385) likewise has no loading guard. A slow network could allow double-submission: the second submit fires before the first round-trip completes, resulting in two `Governance.reject/3` calls for the same approval ID. The facade returns `{:error, :not_pending}` on the second call (which is handled), but the second network round-trip is avoidable and can cause confusing flash ordering.

The Send button in `chat_live.ex` correctly uses `phx-submit-loading:opacity-50` as the pattern.

**Fix:** Add `phx-submit-loading:opacity-50 phx-submit-loading:pointer-events-none` class (or equivalent `disabled` attribute) to the Approve, Reject, and Defer action controls.

---

### WR-04: `conversation_live.ex` `<style>` block contains a large number of hardcoded hex values that are out of scope for the BRAND-04 gate

**File:** `lib/cairnloop/web/conversation_live.ex:432-767`

**Issue:** The `<style>` block embeds ~50 hardcoded hex color values (e.g. `#fbf7ee`, `#d8ccb8`, `#c9b89c`, `#a94f30`, `#7c5430`, `#f5efe3`, `#fee2e2`, etc.) directly in the CSS class definitions. These are not in `var(--cl-X, #hex)` form so the BRAND-04 gate does not flag them. However, CLAUDE.md mandates "Brand tokens over hardcoded hex (primary `var(--cl-primary, #A94F30)`)". These bypass the semantic token layer entirely — a future brand color update would require hunting through the inline style block rather than a single token change. Dark-mode variants in `[data-theme="dark"]` also do not apply because these values are in fixed-class CSS, not CSS custom property references.

The existing pattern in `inbox_live.ex` and `chat_live.ex` uses inline `style=` attributes with `var(--cl-...)` tokens rather than a `<style>` class block with hex values. The `conversation_live.ex` style block predates the token mandate and was not addressed in this phase.

**Fix:** Phase-29 does not seal this file's style block, so flagging for the next token-migration pass. Canonical replacements exist for every hex value used:
- `#fbf7ee` / `#f5f0e6` → `var(--cl-bg)` / `var(--cl-surface)`
- `#a94f30` → `var(--cl-primary)`
- `#fee2e2` → `var(--cl-danger)` with opacity or `var(--cl-danger-soft)`
- Text colors `#2f241d`, `#31261d`, `#4c4033` → `var(--cl-text)`, `var(--cl-text-muted)`

---

## Info

### IN-01: `open_result/3` silently ignores the `new_tab?` option passed by all callers

**File:** `lib/cairnloop/web/search_modal_component.ex:585-597`

**Issue:** Every call site passes `new_tab?: <bool>` to `open_result/3` (lines 250, 279) and `open_active_result/2` (lines 272, 582), but both `open_result` clauses use `_opts` — the option is discarded. All result opens use `push_navigate/2`, which navigates in the same tab. Cmd/Ctrl+click and the keyboard shortcut that sets `new_tab?: true` silently do the same thing as a regular click. The UI implies new-tab support that doesn't exist.

**Fix:** Either implement new-tab navigation via `push_event` + a JS hook, or remove the `new_tab?` compute logic (`new_tab_shortcut?/1`, `new_tab` params) to eliminate the dead code and the misleading shortcut signal.

---

### IN-02: `render_bulk_body/1` in `InboxLive` returns a plain string placeholder, not a rendered template

**File:** `lib/cairnloop/web/inbox_live.ex:590-594`

**Issue:** The function is documented as "mirrors the default content string in `lib/cairnloop/outbound.ex`" and produces `"Outbound message using template: #{template_id}"`. The integration test (`bulk_recovery_live_test.exs:129`) asserts exactly this string, locking in the placeholder behavior. If the outbound module's default string ever diverges (or is enhanced for real personalization in a future phase), the snapshot displayed in the modal will silently mismatch what is actually sent to recipients — breaking the T-25-03 snapshot-integrity guarantee.

This is a design debt note, not a bug at current scope (D-07 explicitly defers personalization). Calling it out so the discrepancy is tracked for the phase that introduces real template rendering.

**Fix:** No change needed now. When real template rendering is introduced, `render_bulk_body/1` should call the same render path used by `Outbound.bulk_trigger/2` so the modal body and the sent body share a single source of truth.

---

_Reviewed: 2026-05-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
