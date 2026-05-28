---
phase: 30
slug: kb-editorial-polish-t-10-09-t-10-11-closure
status: verified
threats_open: 0
asvs_level: L1
created: 2026-05-28
---

# Phase 30 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| operator browser URL → Editor.mount/3 | Untrusted URL params (`suggestion_id`, `handoff`) cross into the LiveView; the editor must not preload reviewed `proposed_markdown` from a bare/forged URL. | Suggestion content (sensitive article draft) |
| SuggestionReview/ConversationLive → EditorHandoff.sign | The only legitimate token minters; they attest a deliberate "open for manual edit" by including the `manual_edit_opened_at` marker. | Auditable handoff intent |
| EditorHandoff token → Plug.Crypto.verify | Signature integrity boundary; HMAC + max-age enforced by the framework, never hand-rolled. | Token payload (suggestion_id, article_id, marker) |
| web layer → KnowledgeAutomation/KnowledgeBase facades | Arch invariant #5 — all reads/writes cross the narrow facade, not direct Repo queries. | Article/suggestion data (tenant-scoped) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-10-09 | Repudiation | `record_editor_handoff/2` (KnowledgeAutomation) + `manual_edit_changeset/2` (ArticleSuggestion) | mitigate | Durable DB write of `manual_edit_opened_at = now_fn(opts).()` on every editor open. Both minting entry points (`suggestion_review.ex:157`, `conversation_live.ex:174`) call `record_editor_handoff/2` before `sign/5`. Test pins `now_fn` and asserts changeset carries pinned timestamp. | closed |
| T-10-11 | Spoofing / Information disclosure | `EditorHandoff.verify!/2` (web wrapper) + `assert_handoff_marker/1` | mitigate | Three-step `with` pipeline: (1) `Token.decode/1`, (2) `assert_handoff_marker/1` requires `is_binary(v) and v != ""` on decoded `"manual_edit_opened_at"`, (3) `non_marker_attrs` equality excluding marker. All `else` branches raise `Ecto.NoResultsError`. Test covers no-marker `assert_raise` path. | closed |
| T-30-01 | Tampering | `EditorHandoff` token | mitigate | `Plug.Crypto.verify/4` constant-time HMAC check; tampered token returns `{:error, _}` from `Token.decode/1`, routed to fail-closed `else` raise. No double-decode (zero `Token.verify` calls in web wrapper). | closed |
| T-30-02 | Elevation / replay | `EditorHandoff` token | mitigate | `@max_age 1800` (30 min) enforced by `Plug.Crypto.verify` in `decode/1`; expired tokens return `{:error, :expired}` → fail-closed raise. Token-shape change invalidates pre-deploy tokens (acceptable — minted at click time, short-lived). | closed |
| T-30-03 | Information disclosure | cross-tenant read via new facades | mitigate | `get_article_suggestion!` and `get_gap_candidate!` thread `opts` through `apply_scope/2` + `enforce_scope!/3`. `list_articles/1` accepts scope opts (reserved; Article has no tenant fields yet). | closed |
| T-10-10 | Tampering | authoring-target seam (knowledge_automation.ex domain) | accept (deferred) | Out of scope — domain-layer threat deferred to vM015 per STATE.md vM014 SECURITY split. | closed |
| T-10-12 | Tampering | `suggest_article/2` gap-candidate prep (domain) | accept (deferred) | Out of scope — deferred to vM015. | closed |
| T-10-13 | Spoofing | `suggest_revision/2` stale gate inputs (domain) | accept (deferred) | Out of scope — deferred to vM015. | closed |
| T-30-SC | Tampering | npm/pip/cargo installs | n/a | Zero new package dependencies this phase (RESEARCH Package Legitimacy Audit). No legitimacy checkpoint required. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-30-01 | T-10-10 | Domain authoring-target threat deferred to vM015 — out of scope for this KB editorial polish phase; separate SECURITY split documented in STATE.md. | gsd-security-auditor | 2026-05-28 |
| AR-30-02 | T-10-12 | `suggest_article/2` gap-candidate prep threat deferred to vM015 — different file/domain path from Phase 30 changes. | gsd-security-auditor | 2026-05-28 |
| AR-30-03 | T-10-13 | `suggest_revision/2` stale gate inputs deferred to vM015 — domain-only concern, no Phase 30 code touches this path. | gsd-security-auditor | 2026-05-28 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-28 | 9 | 9 | 0 | gsd-security-auditor (sonnet) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-28
