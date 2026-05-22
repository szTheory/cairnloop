# Validation Plan: LiveView Markdown Authoring Interface

This document outlines the testing strategy for Phase 2.

## Test Coverage
- `test/cairnloop/web/knowledge_base_live_test.exs` MUST verify the Markdown editor renders the preview side-by-side using Earmark and debounced phx-change events.
- `test/cairnloop/knowledge_base_test.exs` MUST verify the draft vs published logic: saving an edit to a published revision MUST create a new draft (N+1), while saving an edit to a draft MUST update the draft.

## Manual Verification
- Navigate to the Knowledge Base section in the LiveView dashboard.
- Edit an article using Markdown.
- Verify real-time HTML preview updates without full page reloads.
- Verify saving creates a draft if latest is published.