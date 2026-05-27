---
status: partial
phase: 27-realistic-demo-fixtures
source: [27-VERIFICATION.md]
started: 2026-05-27T17:22:00Z
updated: 2026-05-27T17:22:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Adopter-visible dashboard on first boot
expected: |
  After `cd examples/cairnloop_example && mix setup` (or `mix ecto.reset`) + `mix phx.server` + opening `/support`, the operator sees:
    - inbox with 12+ conversations distributed across `:new` / `:open` / `:awaiting_customer` / `:resolved` cohorts (4 each, 16 total) with ContextProvider snippets rendering customer details for each of the 5 demo customer identities (demo_user_acme_billing, demo_user_globex_seats, demo_user_initech_billing, demo_user_umbrella_ci, demo_user_hooli_tokens);
    - KB Index showing 5 articles, including a multi-revision tab on "Rotating an expired token" with a `:archived` v1 + `:published` v2;
    - cmd+k search returning lex-ordered hits for article titles (zero-vector mode without `OPENAI_API_KEY`);
    - `/support/knowledge-base/gaps` showing 3 inspectable gap candidates with scored evidence snippets;
    - `/support/knowledge-base/suggestions` showing 1 `:ready_for_review` (sealed `:ready`) ArticleSuggestion with citation chips for `[1]/[2]`.
why_human: |
  This is the FIX-01..FIX-04 acceptance check the ROADMAP success criteria were written for. Each row count is automated; the dashboard rendering, brand-voice tone of customer/operator copy, and visual coherence are editorial and not deterministically testable. Workspace baseline is REPO-UNAVAILABLE (Postgres on localhost:5433) — run when DB is up.
result: [pending]

### 2. Brand voice on seeded copy
expected: |
  Every seeded subject, customer message, operator reply, internal note, article paragraph, and the `proposed_markdown` for the seeded suggestion reads as calm, fail-closed, reason-forward, and honest (per `prompts/cairnloop_brand_book.md` §5.5 and §7.5). No raw Elixir atoms or raw JSON surface in any operator- or customer-facing string.
why_human: |
  Tone-of-voice is editorial; no automated check can pin it. Spot-check at least 3 conversations per cohort + all 5 articles + the 1 suggestion.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
