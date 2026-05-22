# Phase 2: LiveView Markdown Authoring Interface - Research

**Researched:** 2024-05-17
**Domain:** Elixir/Phoenix LiveView Markdown Editor
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Markdown Parsing:** We will use `earmark` (`~> 1.4`) as the Markdown parser.
- **UI Pattern (Side-by-Side LiveView):** The editor will use a LiveView (`Cairnloop.Web.KnowledgeBaseLive.Editor`) containing two primary panes:
  1. A `<textarea>` bound with `phx-change` and `phx-debounce="300"`.
  2. A preview `<div>` rendering `Phoenix.HTML.raw(Earmark.as_html!(content))`.
- **State Management:** The LiveView will maintain the state of the current `Article` and its active `Revision`. When the operator saves a draft or publishes, the LiveView will call the core context `Cairnloop.KnowledgeBase` to insert a *new* `Revision` or update a draft. A published revision is locked (due to immutability from Phase 1), so editing a published article implies creating a new draft revision starting at `version = latest_version + 1`.
- **WYSIWYG Avoidance:** Strict avoidance of rich text editors (like Quill or Trix).

### the agent's Discretion
None explicitly stated in CONTEXT.md.

### Deferred Ideas (OUT OF SCOPE)
None explicitly stated in CONTEXT.md.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M008-REQ-02 | LiveView dashboard provides a Markdown-native authoring interface with side-by-side preview for operators. | Use `Cairnloop.Web.KnowledgeBaseLive.Editor`, add `earmark` dependency, set up `phx-change` with debounce. Implements Draft/Publish logic mapped to immutable Revisions. |
</phase_requirements>

## Summary

This phase implements the LiveView-based Markdown authoring interface for the Knowledge Base. The UI follows a side-by-side editor/preview pattern. Because of the immutability rules established in Phase 1 (a published `Revision` is locked), editing an already published article requires creating a new draft `Revision` with an incremented version number. We'll use `earmark` for pure-Elixir Markdown parsing.

**Primary recommendation:** Implement `Cairnloop.Web.KnowledgeBaseLive.Editor` with a split-pane layout, use `Earmark.as_html!` for real-time preview, and expose necessary CRUD functions in `Cairnloop.KnowledgeBase` context to handle draft vs. published revision states.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Real-time Markdown Preview | Frontend Server (LiveView) | Browser (DOM updates) | Handled server-side with `Earmark` to ensure parsing matches Elixir's pure functions. Debounced `phx-change` sends text to LiveView, which replies with rendered HTML. |
| Revision Versioning Logic | API / Backend (Context) | Database | The `Cairnloop.KnowledgeBase` context must enforce the logic: "if latest is published, a save creates version N+1 draft". |
| UI State Management | Frontend Server (LiveView) | — | LiveView socket assigns hold the current article and working revision. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `earmark` | `~> 1.4` | Markdown parsing | Pure Elixir, very fast, heavily adopted in the ecosystem, strict parsing without DOM side effects. |

**Installation:**
```bash
mix deps.get
```
*(Need to manually add `{:earmark, "~> 1.4"}` to `mix.exs` dependencies)*

## Architecture Patterns

### System Architecture Diagram

```
[Operator Browser] 
    │    ▲
    │    │ (LiveView WebSockets)
    ▼    │
[KnowledgeBaseLive.Editor]
    │    │ 
    │    │ Earmark.as_html!()
    ▼    ▼
[Cairnloop.KnowledgeBase Context] 
    │
    │ (Checks latest revision state)
    ▼
[PostgreSQL Database]
```

### Recommended Project Structure
```
lib/cairnloop/web/
├── knowledge_base_live/
│   ├── editor.ex        # Side-by-side editor LiveView
│   ├── index.ex         # Listing of Knowledge Base articles
│   └── editor.html.heex # Template for editor
```

### Pattern 1: Debounced LiveView Text Area
**What:** Preventing server overload during typing by debouncing the `phx-change` event.
**When to use:** Text editors or search inputs.
**Example:**
```html
<form phx-change="update_content">
  <textarea name="content" phx-debounce="300" class="...">
    <%= @content %>
  </textarea>
</form>
```

### Pattern 2: Draft vs Publish Workflow
**What:** When an article is edited, the context must determine whether to update an existing draft or create a new one based on the latest revision's state.
**When to use:** Whenever the user clicks "Save" or "Publish".
**Example:**
```elixir
def save_revision(article_id, content, state) do
  latest = get_latest_revision(article_id)
  if latest && latest.state == :published do
    # Create new draft revision version N+1
    create_new_revision(article_id, content, latest.version + 1, state)
  else
    # Update existing draft
    update_revision(latest, content, state)
  end
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown Parsing | Custom Regex | `earmark` | Edge cases in Markdown spec, performance, avoiding complex regex maintenance. |
| Client-Side Debouncing | Custom JS timeouts | `phx-debounce` | Built-in LiveView feature, zero custom JS required. |

**Key insight:** Keeping the parsing server-side with `earmark` means our future chunking phase (Phase 3) can rely on the exact same parser/ast logic if needed, preventing discrepancies between UI and background processing. WYSIWYG editors are strictly forbidden to ensure clean semantic chunking.

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None | None - Greenfield feature inside existing db |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

## Common Pitfalls

### Pitfall 1: XSS from Markdown
**What goes wrong:** Operators inject malicious script tags.
**Why it happens:** Earmark allows HTML by default unless sanitized or explicitly stripped.
**How to avoid:** Ensure Earmark is configured properly if untrusted users have access. (Since these are operators, it's less critical, but still good practice to consider `Earmark` options for stripping malicious HTML if needed).

### Pitfall 2: Overwhelming the Server
**What goes wrong:** Every keystroke sends a large payload to LiveView.
**Why it happens:** Missing `phx-debounce`.
**How to avoid:** Always use `phx-debounce="300"` (or higher) on the textarea.

## Code Examples

### Rendering Earmark in LiveView
```elixir
def handle_event("update_content", %{"content" => content}, socket) do
  # In a real app, handle Earmark errors/warnings gracefully.
  {:ok, html, _} = Earmark.as_html(content)
  {:noreply, assign(socket, content: content, preview_html: Phoenix.HTML.raw(html))}
end
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Operator inputs are trusted / internal | Pitfalls | If public users author, XSS vulnerability could exist if Earmark is not configured to sanitize. |

## Open Questions

1. **Routing (RESOLVED)**
   - What we know: The LiveView will live under the dashboard.
   - What's unclear: The exact URL paths for the KB.
   - Resolution: Add `live("/knowledge-base", Cairnloop.Web.KnowledgeBaseLive.Index)` and `live("/knowledge-base/:id/edit", Cairnloop.Web.KnowledgeBaseLive.Editor)` to `Cairnloop.Router` inside the `:cairnloop_dashboard` live session.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified beyond Hex packages).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| M008-REQ-02 | Markdown editor renders preview | liveview | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | ❌ Wave 0 |
| M008-REQ-02 | Context handles draft vs published | unit | `mix test test/cairnloop/knowledge_base_test.exs` | ✅ Wave 0 (needs update) |

### Sampling Rate
- **Per task commit:** `mix test`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/cairnloop/web/knowledge_base_live_test.exs` — covers M008-REQ-02.
- [ ] Updates to `test/cairnloop/knowledge_base_test.exs` for new `create/update` revision workflows.

## Sources

### Primary (HIGH confidence)
- Project Context - `.planning/milestones/M008-phases/M008-S02-CONTEXT.md`
- Codebase Schemas - `Cairnloop.KnowledgeBase.Article` and `Revision`
- Earmark documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Earmark is the standard Elixir markdown parser.
- Architecture: HIGH - LiveView setup is straightforward and dictated by CONTEXT.md.
- Pitfalls: HIGH - Standard LiveView/Debounce patterns.

**Research date:** 2024-05-17
**Valid until:** 2024-06-17