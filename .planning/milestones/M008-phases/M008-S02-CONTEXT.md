# M008-S02 Context: LiveView Markdown Authoring Interface

## Goal
Enable operators to securely write and preview Knowledge Base articles in Markdown, avoiding RAG-destroying WYSIWYG HTML.

## Requirements
- **M008-REQ-02**: LiveView dashboard provides a Markdown-native authoring interface with side-by-side preview for operators.

## Success Criteria
1. Operator can navigate to a "Knowledge Base" section in the LiveView dashboard.
2. Operator can author an article using a native Markdown editor and see a real-time, side-by-side preview.
3. Operator can save drafts and publish new revisions seamlessly.

## Context & Architectural Decisions

### 1. Markdown Parsing
- **Decision:** We will use `earmark` (`~> 1.4`) as the Markdown parser.
- **Rationale:** It is pure Elixir, safe, and heavily adopted in the ecosystem. Since KB articles are generally concise, the parsing overhead on the server is negligible. It keeps the architecture idiomatic Elixir without bringing in JS libraries or NIF dependencies (`mdex`).

### 2. UI Pattern (Side-by-Side LiveView)
- **Decision:** The editor will use a LiveView (`Cairnloop.Web.KnowledgeBaseLive.Editor`) containing two primary panes:
  1. A `<textarea>` bound with `phx-change` and `phx-debounce="300"`.
  2. A preview `<div>` rendering `Phoenix.HTML.raw(Earmark.as_html!(content))`.
- **Rationale:** Debouncing the text input prevents overwhelming the server with change events on every keystroke, striking a balance between immediate feedback and system performance.

### 3. State Management
- **Decision:** The LiveView will maintain the state of the current `Article` and its active `Revision`. 
- **Rationale:** When the operator saves a draft or publishes, the LiveView will call the core context `Cairnloop.KnowledgeBase` to insert a *new* `Revision` or update a draft. A published revision is locked (due to immutability from Phase 1), so editing a published article implies creating a new draft revision starting at `version = latest_version + 1`.

### 4. WYSIWYG Avoidance
- **Decision:** Strict avoidance of rich text editors (like Quill or Trix).
- **Rationale:** WYSIWYG HTML often contains unpredictable DOM structures, inline styles, and `<span>` spans that break semantic chunking algorithms during RAG processing. Strict Markdown ensures that headers (H2/H3) are perfectly parsable by Phase 3's chunking logic.
