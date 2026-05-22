# M009-S01 Discussion Log

**Date:** 2026-05-17
**Mode:** Discuss all, research-backed, decisive defaults

## User guidance captured

- Discuss all major gray areas for M009 Phase 1.
- Use subagents to research pros, cons, tradeoffs, idiomatic Elixir/Phoenix/Ecto/Oban patterns, and lessons from successful products/libraries.
- Prioritize coherent, one-shot recommendations that reduce decision fatigue.
- Emphasize great software architecture, developer ergonomics, principle of least surprise, and user trust.
- Pull applicable project guidance from `prompts/`.
- Bias GSD toward shifting routine gray-area decisions left unless they are genuinely high impact.

## Areas discussed

### 1. Resolved evidence shape

**Options considered**
- Full transcript
- Summary-only
- Resolution-note-only
- Structured evidence record

**Locked recommendation**
- Use a structured resolved-evidence record as the indexed assistive artifact.
- Keep raw transcript material for citations/audit/regeneration, but do not index it as the primary retrieval document.

**Why**
- Better trust semantics than transcript search
- Better recall and inspectability than summary-only
- Better consistency than relying on human-authored notes alone

### 2. Retrieval API boundary

**Options considered**
- Single retriever boundary only
- Fully separate KB and resolved-evidence public APIs
- Facade over specialized providers

**Locked recommendation**
- Expose one internal retrieval facade over specialized provider internals.

**Why**
- Gives callers one paved-road API
- Preserves explicit separation between canonical KB and assistive evidence
- Prevents LiveViews/workers from bypassing policy and trust boundaries

### 3. Hybrid ranking behavior

**Options considered**
- Parallel keyword + vector retrieval with deterministic fusion
- Vector-first with keyword fallback
- Keyword-first with vector fallback
- Learned or dynamically weighted ranking

**Locked recommendation**
- Use deterministic hybrid retrieval with parallel FTS + vector candidate generation and transparent fusion.

**Why**
- Most predictable for operators and downstream AI flows
- Best balance of exact-term recall and natural-language recall
- Easier to trace, tune, and explain than opaque learned ranking

### 4. Index lifecycle

**Options considered**
- Minimal trigger-only lifecycle
- Trigger + explicit rebuild/replay support
- Heavy operational workflows

**Locked recommendation**
- Use trigger-based indexing plus explicit replay/rebuild primitives for developers.

**Why**
- Durable enough for a real library surface
- Preserves host-owned ops without bloating Phase 1 into a control plane
- Fits Oban/Ecto patterns and makes failure recovery boring

## Research themes carried into the final decisions

- Strong support products keep knowledge as the primary truth source and treat historical cases as secondary evidence.
- Permission and visibility checks must happen before answer display or ranking.
- Search and drafting should share one stable retrieval contract, not duplicate logic.
- Hybrid retrieval is safest when ranking remains inspectable and deterministic.
- Recovery primitives matter early; best-effort background work is not enough for a host-owned library.
- Cairnloop should remain embedded, calm, operator-grade, and explicitly not an omnichannel black-box helpdesk clone.

## Outcome

The resulting context intentionally locks the major implementation choices for M009 Phase 1 so downstream research and planning agents can proceed with minimal additional user questioning.
