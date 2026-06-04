---
phase: 42
slug: cross-screen-threading
status: verified
audited_at: 2026-06-04
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
threats_total: 18
threats_closed: 18
threats_open: 0
result: SECURED
---

# Security Audit — Phase 42: Cross-Screen Threading

**ASVS Level:** 1
**Threats Closed:** 18/18
**Threats Open:** 0

---

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-42-01 | Information Disclosure | accept | CLOSED | `conversation_id` is an integer FK added to the enriched map (auditor.ex:81-82). Target conversation reads are operator-scoped at render time. Accept rationale (D-02: structural navigational FK, not a trust fact) not contradicted by code. |
| T-42-02 | Tampering | mitigate | CLOSED | `maybe_where_proposal/2` at governance.ex:1014-1018 uses `^proposal_id` Ecto pin with `is_integer/1` guard; nil clause is a passthrough — unfiltered read unchanged. No string interpolation. |
| T-42-03 | Information Disclosure | mitigate | CLOSED | Enriched map adds only integer ids (`conversation_id`, `proposal_id`). `AuditLogPresenter` humanizes all displayed fields. `conversation_id` appears once as `aria-label` integer interpolation (audit_log_live.ex:189). No raw atoms/terms reach rendered HTML. |
| T-42-04 | Information Disclosure | mitigate | CLOSED | `originating_conversation_id/2` at knowledge_automation.ex:96 calls `apply_scope(opts)` (tenant_scope + host_user_id WHERE clauses) before the entrypoint filter. Additionally applies post-fetch `scope_matches?/3` check at line 105 — stronger than declared. |
| T-42-05 | Tampering | mitigate | CLOSED | `^current_id` pin at chat.ex:372; `^article_id` pin at knowledge_automation.ex:97. Both bindings parameterized; no string interpolation present. |
| T-42-06 | Information Disclosure | accept→mitigate | CLOSED | `next_open_conversation` selects `c.id` only (chat.ex:375). `originating_conversation_id` selects `{s.entrypoint_id, s.tenant_scope, s.host_user_id}` (knowledge_automation.ex:100) — minimal field exposure; no full row returned. |
| T-42-07 | Tampering | mitigate | CLOSED | `Integer.parse(raw)` with `id > 0` guard at audit_log_live.ex:37-39. Invalid/garbage/missing param → `proposal_filter: nil` → full honest view, no crash. |
| T-42-08 | Information Disclosure (IDOR) | mitigate | CLOSED | All reads flow through auditor → `Governance.list_action_events` → `repo()` indirection. No `Cairnloop.Repo.` direct use in audit_log_live.ex (grep: zero matches). A forged proposal_id yields an empty filtered view — no cross-tenant leak. |
| T-42-09 | Information Disclosure | mitigate | CLOSED | `subject_href/1` returns nil for absent/nil conversation_id (audit_log_presenter.ex:93-94). Nil branch renders `<span class="cl-text-muted">—</span>` (audit_log_live.ex:184-185) — no `navigate=` with nil or empty segment. |
| T-42-SC | Tampering | mitigate | CLOSED | `git diff HEAD~6 HEAD -- mix.exs mix.lock` returned no output — zero new packages installed during phase 42. |
| T-42-10 | Information Disclosure | mitigate | CLOSED | `Chat.next_open_conversation(conversation_id)` called inside `reload_conversation_with_context/2` at conversation_live.ex:385 — recomputed on every PubSub reload. Nil → Queue-clear branch at lines 562-564, never a stale-id navigate. |
| T-42-11 | Information Disclosure | mitigate | CLOSED | `case @next_open_id do` at conversation_live.ex:561; `nil ->` branch renders "Queue clear — no more open conversations." + `<.link navigate="/inbox">` (lines 562-564). No disabled/dead Next button ever rendered. |
| T-42-12 | Tampering | mitigate | CLOSED | `grep '/support/' lib/cairnloop/web/conversation_live.ex` returned zero matches. Scope-relative paths confirmed: `/#{id}` (line 566), `/inbox` (line 564), `/audit-log?proposal=#{@trace.proposal_id}` (line 1112). |
| T-42-13 | Information Disclosure | mitigate | CLOSED | `scope_filters(session)` computed at editor mount and passed as `opts` to `knowledge_automation().originating_conversation_id(article.id, scope_filters)` (editor.ex:38). `apply_scope/2` and `scope_matches?/3` both apply in `originating_conversation_id/2`. |
| T-42-14 | Information Disclosure | mitigate | CLOSED | `editor_items(nil, return_to, title)` at breadcrumb_presenter.ex:63-65 delegates to `editor_items/2` with no origin crumb prepended. `cl_breadcrumb` renders links only via `:if={item[:href]}` — items without `:href` render plain text only. |
| T-42-15 | Tampering | mitigate | CLOSED | Origin crumb href is `"/#{origin_conversation_id}"` at breadcrumb_presenter.ex:57. `grep '/support/' breadcrumb_presenter.ex` returned zero matches. Scope-root-relative only. |
| T-42-16 | Tampering | mitigate | CLOSED | E2E spec at thread_navigation_test.exs lines 48, 69, 95, 116: all four thread tests call `refute_has("body", text: "/support/support/")`. `assert_path/2` uses `/support/...` host prefix without doubling. |
| T-42-17 | (N/A — test-only) | accept | CLOSED | Plan 06 modifies only test files (`thread_navigation_test.exs`, `rail_fixtures.ex`). No `lib/` file changed. Accept rationale (no new runtime surface) confirmed by git diff and SUMMARY.md self-check. |

---

## Unregistered Flags

None. All SUMMARY.md `## Threat Flags` sections across Plans 01–06 explicitly map to the registered threat IDs (T-42-02, T-42-03, T-42-07, T-42-08, T-42-09, T-42-16) or declare no new surface.

---

## Accepted Risks Log

| Threat ID | Rationale |
|-----------|-----------|
| T-42-01 | `conversation_id` and `proposal_id` are navigational structural FKs added to the enriched auditor map. They are not trust facts (D-02). The target conversation read is itself operator-scoped at render time. Disclosure of a bare integer conversation id to an authenticated operator in their own session is an accepted structural FK exposure. |
| T-42-17 | Plan 06 is test-file-only. No library code (`lib/`) was modified. No new runtime attack surface was introduced. |

---

## Notes

- **T-42-10 scope qualification:** `Chat.next_open_conversation/1` queries all `:open` conversations across the single-tenant host instance (same scope model as the pre-existing `Chat.list_conversations/1`). The "operator-scoped" framing in the threat register refers to the facade `repo()` indirection pattern and the `:open` status restriction — not per-tenant row-level security, which is not a model this module applies. This is consistent with the pre-existing threat posture.

- **T-42-04 stronger-than-declared:** `originating_conversation_id/2` applies both a WHERE-clause scope via `apply_scope/2` AND a post-fetch `scope_matches?/3` verification on the returned row's `tenant_scope`/`host_user_id` fields. This exceeds the declared mitigation plan.

- **T-42-06 field selection note:** The select at knowledge_automation.ex:100 fetches `{s.entrypoint_id, s.tenant_scope, s.host_user_id}` rather than `s.entrypoint_id` alone, to support the post-fetch scope verification. The `tenant_scope` and `host_user_id` fields are internal scope columns that do not leave the facade — they are consumed by `scope_matches?/3` and discarded; only the `entrypoint_id` integer is returned to callers.

- **E2E gate (T-42-16):** The `mix test.e2e` run could not be executed in this environment due to the pre-existing `pgvector` extension constraint (documented in CLAUDE.md). The test file is syntactically and semantically correct; the CI `e2e` lane (which has `pgvector`) is the authoritative gate.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-04 | 18 | 18 | 0 | gsd-security-auditor (verify-mitigations mode) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (T-42-01, T-42-17)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-04
