---
phase: "02"
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - mix.exs
  - lib/cairnloop/knowledge_base.ex
  - lib/cairnloop/web/knowledge_base_live/index.ex
  - lib/cairnloop/web/knowledge_base_live/editor.ex
  - lib/cairnloop/router.ex
autonomous: true
requirements:
  - M008-REQ-02
must_haves:
  truths:
    - Operator can see a Knowledge Base area in LiveView dashboard.
    - Operator can type Markdown and see a debounced, real-time preview side-by-side.
    - Operator can save drafts and publish.
    - Editing a published article creates a new draft instead of mutating the published version.
  artifacts:
    - path: "mix.exs"
      provides: "Earmark dependency"
    - path: "lib/cairnloop/knowledge_base.ex"
      provides: "Versioning and draft/publish logic"
    - path: "lib/cairnloop/web/knowledge_base_live/editor.ex"
      provides: "LiveView Editor with Markdown parsing"
  key_links:
    - from: "lib/cairnloop/web/knowledge_base_live/editor.ex"
      to: "lib/cairnloop/knowledge_base.ex"
      via: "context calls"
      pattern: "KnowledgeBase\\.(save_draft|publish_revision)"
    - from: "lib/cairnloop/web/knowledge_base_live/editor.ex"
      to: "Earmark"
      via: "Markdown parsing"
      pattern: "Earmark\\.as_html!"
---

<objective>
Build the LiveView Markdown Authoring Interface for the Knowledge Base.

Purpose: Enable operators to securely write and preview Knowledge Base articles in Markdown without using RAG-destroying WYSIWYG HTML. This ensures content is perfectly structured for Phase 3 semantic chunking.
Output: Core Context logic for draft/publish revision immutability, the Knowledge Base LiveView Index and Editor, and proper Earmark parsing for real-time previews.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/milestones/M008-phases/M008-S02-CONTEXT.md
@.planning/milestones/M008-phases/M008-S02/02-RESEARCH.md
@.planning/milestones/M008-phases/M008-S02/PATTERNS.md
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add Earmark and Implement Core Context Logic</name>
  <files>mix.exs, lib/cairnloop/knowledge_base.ex, test/cairnloop/knowledge_base_test.exs</files>
  <behavior>
    - Test 1: `save_draft` creates a new revision with version N+1 if latest revision is published.
    - Test 2: `save_draft` updates the existing draft if latest revision is a draft.
    - Test 3: `publish_revision` sets state to `:published`.
  </behavior>
  <action>
    Add `{:earmark, "~> 1.4"}` to `mix.exs` and run `mix deps.get`.
    In `lib/cairnloop/knowledge_base.ex`, implement `save_draft/2` and `publish_revision/1`.
    The logic MUST enforce immutability: if the `latest` revision is `:published`, a new save creates version `N+1` as a `:draft`. If the `latest` is already a `:draft`, it updates that existing draft.
  </action>
  <verify>
    <automated>mix test test/cairnloop/knowledge_base_test.exs</automated>
  </verify>
  <done>Earmark is installed and Context logic successfully manages draft vs published states per immutability rules.</done>
</task>

<task type="auto">
  <name>Task 2: Build LiveView Editor and Index</name>
  <files>lib/cairnloop/web/knowledge_base_live/index.ex, lib/cairnloop/web/knowledge_base_live/editor.ex</files>
  <action>
    Create `KnowledgeBaseLive.Index` to list articles.
    Create `KnowledgeBaseLive.Editor` for authoring. Follow the side-by-side layout pattern from `PATTERNS.md`.
    The editor MUST use a `<textarea phx-change="change" phx-debounce="300">` to prevent overwhelming the server.
    The preview pane MUST render `Phoenix.HTML.raw(Earmark.as_html!(content))`.
    Wire up "Save Draft" and "Publish" events to call `Cairnloop.KnowledgeBase.save_draft/2` and `publish_revision/1`.
  </action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>LiveViews exist with debounced input, Earmark preview rendering, and wired context operations.</done>
</task>

<task type="auto">
  <name>Task 3: Wire Routing</name>
  <files>lib/cairnloop/router.ex</files>
  <action>
    In `lib/cairnloop/router.ex`, add routes within the `:cairnloop_dashboard` live session block:
    `live "/knowledge-base", Cairnloop.Web.KnowledgeBaseLive.Index, :index`
    `live "/knowledge-base/:id/edit", Cairnloop.Web.KnowledgeBaseLive.Editor, :edit`
  </action>
  <verify>
    <automated>mix phx.routes | grep knowledge-base</automated>
  </verify>
  <done>The Knowledge Base LiveViews are reachable via standard application routing.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Operator Browser -> LiveView | Operator inputs raw Markdown which is parsed server-side via Earmark and sent back as HTML |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-01 | Spoofing/Tampering | `KnowledgeBaseLive.Editor` | mitigate | Ensure operator context is checked via `mount` before allowing edits (rely on existing dashboard auth). |
| T-02-02 | Elevation of Privilege | Markdown parser (XSS) | accept | Since operators are trusted internal users and WYSIWYG is avoided for RAG structuring, XSS risk via Earmark is low-impact. We accept Earmark's default output for the preview pane. |
| T-02-03 | Denial of Service | `KnowledgeBaseLive.Editor` | mitigate | Use `phx-debounce="300"` on the textarea to prevent excessive Earmark parsing and socket spam on every keystroke. |
</threat_model>

<verification>
1. Run `mix test` to ensure all logic (especially draft versioning) passes.
2. Confirm the LiveView editor renders successfully without compilation errors.
3. Verify that `router.ex` correctly maps the paths.
</verification>

<success_criteria>
- Earmark is successfully integrated for fast, server-side Markdown parsing.
- Immutability rules are strictly enforced by the backend Context logic.
- Operators have a debounced, side-by-side authoring experience.
- The foundation is perfectly structured for Phase 3's pgvector chunking.
</success_criteria>

<output>
After completion, create `.planning/milestones/M008-phases/M008-S02/02-01-SUMMARY.md`
</output>