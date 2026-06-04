---
status: partial
phase: 38-shared-page-shell-migration
source: [38-VERIFICATION.md]
started: 2026-06-04T03:05:00Z
updated: 2026-06-04T03:05:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Visual consistency across all screens
expected: Navigate to Home, Inbox, `/audit-log`, Settings, and each KB sub-screen (index, editor, gaps, suggestion review) in the running app. Every screen presents the same header height, the same inner content width, and a correctly rendered page title — the cockpit reads as one app, not several. (Structural wiring through `cl_page` is code-verified; this confirms the resulting visual is actually consistent. Phase 45 formally regenerates light+dark screenshots as the pipeline proof.)
result: [pending]

### 2. Live conversation → editor breadcrumb back-link round-trip
expected: Open a conversation from the Audit Log, navigate into the KB editor from that conversation, then click the origin ("Conversation") breadcrumb back link. The editor shows a `cl_breadcrumb` with ≥2 crumbs (Conversation → Knowledge → Editing: &lt;title&gt;); the "Conversation" crumb is a working back link that returns to the originating conversation; the last crumb is the current page (`aria-current`). The raw `/<id>` path is never shown as crumb text.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
