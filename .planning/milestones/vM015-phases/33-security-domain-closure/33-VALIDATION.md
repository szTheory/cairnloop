## Nyquist Coverage Validation

*Backfilled at vM015 close (2026-05-30) by transcribing the existing, passing tests added in
`33-01-SUMMARY.md`. The domain layer already enforced these invariants; phase 33 added the
regression tests that prove it. No production logic changed.*

| Requirement | Test Coverage / Verification | Gap? |
|-------------|------------------------------|------|
| SEC-01 (T-10-10) — reuse only non-published authoring targets | `test/cairnloop/knowledge_automation_test.exs` → `describe "create_or_reuse_authoring_article_for_suggestion/2 (SEC-01)"`: "Given a suggestion with a published authoring_article_id, it rejects reuse and safely creates a new draft article" + "Given a valid draft authoring_article_id, it reuses the target". | NO |
| SEC-02 (T-10-12) — gap-candidate grounding from hydrated evidence only | `test/cairnloop/knowledge_automation_test.exs` → `describe "suggest_article/2 (SEC-02)"`: "gap candidate suggestions disregard caller-supplied evidence and grounding_bundle". | NO |
| SEC-03 (T-10-13) — stale-gate inputs from repo-backed GapEvent + canonical grounding only | `test/cairnloop/knowledge_automation_test.exs` → `describe "suggest_revision/2 (SEC-03)"`: "ignores spoofed gap_events or grounding_bundle in opts". | NO |

**Conclusion**: All three security-closure requirements are covered by explicit regression tests in
`knowledge_automation_test.exs` (headless `mix test`, in the `phase-12-shift-left` CI job). The tests
assert that caller-supplied / spoofed inputs are ignored and that published targets are never reused —
the exact threats T-10-10/12/13. No gaps.
