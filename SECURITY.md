# Security Verification: Phase 10 Citation-Backed Draft Suggestions

- Phase: `10` - `citation-backed-draft-suggestions`
- ASVS Level: `1`
- block_on: `threats_open`
- threats_total: `14`
- threats_open: `5`

## Threat Verification

| Threat ID | Category | Component | Disposition | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| T-10-01 | T | `ArticleSuggestion` persistence | mitigate | CLOSED | Separate host-owned `cairnloop_article_suggestions` table with `proposed_markdown` in [priv/repo/migrations/20260521020000_add_article_suggestions.exs](/Users/jon/projects/cairnloop/priv/repo/migrations/20260521020000_add_article_suggestions.exs:5); schema persists full markdown in [lib/cairnloop/knowledge_automation/article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex:23). |
| T-10-02 | I | embedded evidence snapshot | mitigate | CLOSED | Bounded `citation_target` and `metadata.destination` validation in [lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex:47). |
| T-10-03 | S | revision entrypoint anchor | mitigate | CLOSED | `suggest_revision/2` resolves the published anchor through `get_latest_active_revision/1` and rejects missing anchors in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472) and [lib/cairnloop/knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:9). |
| T-10-04 | D | `GenerateArticleSuggestion` queueing | mitigate | CLOSED | Oban uniqueness keys include `entrypoint_type`, `entrypoint_id`, `base_revision_id`, and `evidence_digest` in [lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:2); job args include the same fields in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1063). |
| T-10-05 | T | stale-article revision gate | mitigate | CLOSED | Stale gate enforces `@window_days 30`, `@minimum_signals 2`, published `base_revision_id`, and article/revision linkage from canonical citation anchors in [lib/cairnloop/knowledge_automation/stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:10) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472). |
| T-10-06 | S | generation grounding boundary | mitigate | CLOSED | Weak or anchorless bundles fail closed before success and persist durable failed suggestions via [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:580), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:646), and worker checks in [lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:14). |
| T-10-07 | S | `SuggestionReview` action set | mitigate | CLOSED | The review surface renders only regenerate, dismiss, and open-for-manual-edit actions in [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:274); no approval or publish events are handled there. |
| T-10-08 | T | suggestion diff / trust presentation | mitigate | CLOSED | Revision diffs derive from `base_revision_id` plus `proposed_markdown` in [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:256) and [lib/cairnloop/web/article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:55); trust/citation wording is presenter-driven in [lib/cairnloop/web/article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:6). |
| T-10-09 | E | editor handoff | mitigate | OPEN | `SuggestionReview` provides `open_for_manual_edit`, but the editor accepts any matching `suggestion_id` directly and does not verify a prior handoff marker or `manual_edit_opened_at` gate in [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82) and [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:90). |
| T-10-10 | T | authoring target seam | mitigate | OPEN | New-article creation starts with `status: :draft`, but reuse of `authoring_article_id` does not verify the target is still non-published in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544). |
| T-10-11 | S | editor preload | mitigate | OPEN | The editor preloads `proposed_markdown` whenever `suggestion_id` is present, without requiring deliberate handoff state beyond URL parameters in [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:16) and [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:84). |
| T-10-12 | T | `suggest_article/2` gap-candidate prep | mitigate | OPEN | The shipped path hydrates candidate evidence, but callers can still bypass it by supplying query/evidence/grounding fields because `hydrate_gap_candidate_request/2` short-circuits on `gap_candidate_grounding_supplied?/1`; generic fallback logic also remains in the shared bundle builder at [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1366) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:824). |
| T-10-13 | S | `suggest_revision/2` stale gate inputs | mitigate | OPEN | The domain loads durable `GapEvent` rows and fresh grounding by default, but `gap_events` and `grounding_bundle` can still be injected through opts, so queueing is not limited to repo-backed stale evidence in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:490) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1470). |
| T-10-14 | I | review-lane suggestion metadata | mitigate | CLOSED | Query, digest, canonical evidence counts, and stale-signal metadata persist in grounding metadata via [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1120), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1137), and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1151). |

## Open Threats

| Threat ID | Expected Mitigation | Files Searched |
| --- | --- | --- |
| T-10-09 | Require a verifiable `open_for_manual_edit` handoff before the editor accepts suggestion content. | [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82), [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:90), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544) |
| T-10-10 | Reuse only non-published authoring targets for new-article suggestions. | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544), [lib/cairnloop/knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:24) |
| T-10-11 | Preload reviewed suggestion markdown only after deliberate handoff, not from a bare `suggestion_id` URL. | [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:11), [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82) |
| T-10-12 | Build gap-candidate grounding only from hydrated candidate evidence and remove caller-supplied bypasses on that path. | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:416), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1366), [lib/cairnloop/web/knowledge_base_live/gaps.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/gaps.ex:30) |
| T-10-13 | Load stale-gate inputs only from repo-backed `GapEvent` rows plus fresh canonical grounding inside the domain. | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1470), [lib/cairnloop/knowledge_automation/stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:15) |

## Accepted Risks Log

None.

## Transfer Log

None.

## Unregistered Flags

None. The required summary files do not contain a `## Threat Flags` section.

---

# Security Verification: Phase 30 — KB Editorial Polish (T-10-09 + T-10-11 Closure)

- Phase: `30` - `kb-editorial-polish-t-10-09-t-10-11-closure`
- ASVS Level: `1`
- block_on: `HIGH`
- threats_total: `9`
- threats_open: `0`

## Threat Verification

| Threat ID | Category | Component | Disposition | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| T-10-09 | Repudiation | `record_editor_handoff/2` + `manual_edit_changeset/2` | mitigate | CLOSED | `record_editor_handoff/2` at `lib/cairnloop/knowledge_automation.ex:86-93` computes `now = now_fn(opts).()` and writes via `ArticleSuggestion.manual_edit_changeset(now) |> repo().update()`. `manual_edit_changeset/2` at `lib/cairnloop/knowledge_automation/article_suggestion.ex:89-91` casts only `:manual_edit_opened_at` (no heavy validate_required re-run). Overwrite-on-each-open idempotency proven by test at `test/cairnloop/knowledge_automation_test.exs:54`. End-to-end test at line 67 pins `now_fn` and asserts `changes.manual_edit_opened_at == pinned_ts`. Both minting entry points call `record_editor_handoff/2` before `sign/5`: `suggestion_review.ex:157` and `conversation_live.ex:174`. |
| T-10-11 | Spoofing / Information disclosure | `EditorHandoff.verify!/2` + `assert_handoff_marker/1` | mitigate | CLOSED | `verify!/2` at `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex:18-28` is a three-step `with` pipeline: (1) `Token.decode/1`, (2) `assert_handoff_marker(payload)` at line 30-33 requiring `is_binary(v) and v != ""` on `"manual_edit_opened_at"` in the decoded payload, (3) `non_marker_attrs` equality check excluding the marker. All `else` branches raise `Ecto.NoResultsError` fail-closed. Bare-URL tokens (no marker) fail step 2. Test at `test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs:57-63` covers the no-marker `assert_raise` case. |
| T-30-01 | Tampering | `EditorHandoff` token | mitigate | CLOSED | `decode/1` at `lib/cairnloop/knowledge_automation/editor_handoff.ex:11-13` is a single `Plug.Crypto.verify/4` call (constant-time HMAC). Tampered tokens return `{:error, _}`. `grep -c 'Token.verify' lib/cairnloop/web/knowledge_base_live/editor_handoff.ex` = 0 (no double-decode). All `else` branches in `verify!/2` raise `Ecto.NoResultsError` (fail-closed). |
| T-30-02 | Elevation / replay | `EditorHandoff` token | mitigate | CLOSED | `@max_age 1800` at `lib/cairnloop/knowledge_automation/editor_handoff.ex:5` is passed as `max_age: @max_age` to `Plug.Crypto.verify` inside `decode/1` at line 12. Expired tokens decode to `{:error, :expired}`, which routes to the fail-closed `else` raise in `verify!/2`. |
| T-30-03 | Information disclosure | cross-tenant read via new facades | mitigate | CLOSED | `record_editor_handoff/2` calls `get_article_suggestion!(suggestion_id, opts)` which threads `opts` through `apply_scope(opts)` (line 74) and `enforce_scope!(opts, ArticleSuggestion)` (line 77). `get_gap_candidate/2` wraps `get_gap_candidate!(id, opts)` which threads `opts` through `apply_scope(opts)` (line 55) and `enforce_scope!(opts, GapCandidate)` (line 59). `list_articles/1` at `lib/cairnloop/knowledge_base.ex:71-76` accepts `opts` for future tenant scope (Article has no tenant fields yet — reserved per D-09). |
| T-10-10 | Tampering | authoring-target seam | accept (deferred) | CLOSED | Deferred to vM015 per STATE.md vM014 SECURITY split. No code mitigation required this phase. |
| T-10-12 | Tampering | `suggest_article/2` gap-candidate prep | accept (deferred) | CLOSED | Deferred to vM015. No code mitigation required this phase. |
| T-10-13 | Spoofing | `suggest_revision/2` stale gate inputs | accept (deferred) | CLOSED | Deferred to vM015. No code mitigation required this phase. |
| T-30-SC | Tampering | npm/pip/cargo installs | n/a | CLOSED | Zero new package dependencies introduced this phase. |

## Accepted Risks Log (Phase 30)

| Risk ID | Threat | Rationale | Deferred To |
| --- | --- | --- | --- |
| T-10-10 | Authoring-target seam tampering | Domain-layer threat; out of scope for vM014 editorial polish phase per STATE.md vM014 SECURITY split | vM015 |
| T-10-12 | `suggest_article/2` gap-candidate prep tampering | Out of scope for vM014 phase | vM015 |
| T-10-13 | `suggest_revision/2` stale gate inputs spoofing | Out of scope for vM014 phase | vM015 |

## Unregistered Flags (Phase 30)

None. All `## Threat Flags` entries in the Phase 30 plan SUMMARYs mapped to existing threat IDs:
- `record_editor_handoff/2` and `get_gap_candidate/2` threading `opts` through `apply_scope/enforce_scope` — mapped to T-30-03.
- `list_articles/1` accepting scope opts (reserved) — mapped to T-30-03.
- `verify!/2` rewrite — mapped to T-10-11.
- Both Plan 03 and Plan 04 SUMMARY.md files report no new unplanned threat surface.
