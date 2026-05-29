# Wave 1 Summary: Security Domain Closure

## Outcomes
Successfully verified and enforced the immutable evidence and state for knowledge automation by closing three domain-layer security threats (T-10-10, T-10-12, T-10-13). 
No production logic changes were required in `lib/cairnloop/knowledge_automation.ex` because the domain layer was already strictly enforcing these constraints; however, explicit tests were missing.

## SEC-01 (T-10-10) Enforce Non-Published Authoring Targets
- Validated that `create_or_reuse_authoring_article_for_suggestion/2` safely delegates to `reusable_authoring_article?` which strictly rejects published articles.
- Added tests asserting that a published authoring_article_id results in a new safe draft instead of unsafe overwrite.

## SEC-02 (T-10-12) Remove Gap Candidate Grounding Bypasses
- Validated that `hydrate_gap_candidate_request/2` unconditionally overwrites caller-supplied `opts[:grounding_bundle]` via `Keyword.put` and strips evidence from `attrs`.
- Added tests proving gap candidate suggestions disregard any spoofed caller-supplied evidence or grounding bundles.

## SEC-03 (T-10-13) Enforce Stale Gate Inputs
- Validated that `build_revision_gate_inputs/3` explicitly queries the database and domain logic rather than falling back to caller opts (`gap_events` and `grounding_bundle`).
- Added tests asserting that `stale_article_signal_module(opts).build_revision_gate` only receives exclusively internally-generated inputs and completely ignores injected `opts`.

All 3 threats are definitively closed by code and proven by tests.
