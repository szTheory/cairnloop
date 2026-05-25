# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-25

### Added
- Host-owned hybrid retrieval corpus (pgvector + PG full-text) via `Cairnloop.Retrieval`
- Operator search with trust, recency, and citation cues
- Citation-backed grounded drafting with clarification and escalation states
- Durable gap-event storage and ranked KB gaps dashboard
- AI-prepared KB draft/revision suggestions with stale-revision gating and citation validation
- Review-gated KB update workflow: approve, reject, defer, publish — with append-only task event history
- In-thread quick-fix KB maintenance launched from live support conversations
- Host-owned governed-action contract: compile-time `use Cairnloop.Tool` with risk tiers and deny-by-default `authorize/2`
- Durable `ToolProposal` + `ToolActionEvent` records with Stripe-style idempotency
- Approval state machine with Oban-backed resume, expiry, and deferral paths
- Three-layer at-most-once execution: Oban unique + terminal guard + SHA-256 per-attempt run key
- Bounded `[:cairnloop, :retrieval, …]` and `Cairnloop.Governance.Telemetry` event namespaces
- Read-only MCP seam (`tools/list`, `initialize`) via optional `Cairnloop.Web.MCP.Router` Plug
