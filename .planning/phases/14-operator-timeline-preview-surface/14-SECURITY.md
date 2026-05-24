---
phase: 14
slug: operator-timeline-preview-surface
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-24
---

# Phase 14 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Register authored at plan time (all 4 PLAN files carried `<threat_model>` blocks);
> mitigations independently verified against implementation by gsd-security-auditor.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| test harness → modules-under-test | Wave 0 tests reference not-yet-existing modules; references must not break the build. | test dispatch (runtime alias / `apply/3`) |
| stored JSONB snapshot → `Preview` live leg | `input_snapshot` rehydrated to call host `preview/1`; attacker-influenced snapshot keys/values cross here. | JSONB keys/values (incl. PII) |
| host tool `preview/1` → LiveView render | third-party host code returns prose that becomes operator-visible. | host-supplied string |
| snapshot maps → operator UI (presenter / DOM) | raw stored values (incl. PII in `input_snapshot`, raw `inspect`'d `policy_snapshot.reason`) flow toward display. | snapshot maps (incl. PII), policy reason |
| operator browser → `handle_event("execute_tool")` | untrusted form params cross into the propose context. | form params |
| blocked-proposal reason → operator UI | failure reasons flow toward operator-visible copy. | scope/policy reason terms |
| per-conversation proposal list → rail render | `governed_actions` assign rendered into the DOM. | proposal records (incl. blocked) |
| Phase 14 trust fields → Phase 15 approval surface | risk that Phase 15 reuses the live prose leg instead of D-16 snapshotted columns. | trust/display fields (forward-compat) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-14-W0-01 | Tampering | Test files referencing undefined modules | mitigate | Runtime alias / `apply/3` / `Function.capture/3` — no compile-time macro expansion of undefined modules. `preview_test.exs:12`, `tool_proposal_presenter_test.exs:12`. `mix compile --warnings-as-errors` exits 0. | closed |
| T-14-01 (T-jsonb) | Denial of Service | `Preview` atom rehydration of JSONB snapshot (D-19) | mitigate | `String.to_existing_atom/1` + `rescue ArgumentError` (`preview.ex:98`); `String.to_atom(` count == **0**. Prevents unbounded-atom-table DoS. | closed |
| T-14-02 | DoS / Availability | host `preview/1` raises / loops / non-string | mitigate | Guard stack `find_tool_module` → `Code.ensure_loaded?` → `function_exported?/3` → `try/rescue` (`preview.ex:76-83`, `call_preview/2` 118-126); non-empty binary gate (line 120) else `:fallback`. Bad host tool degrades one card, never crashes LiveView. | closed |
| T-14-03 | Info Disclosure / Tampering | unregistered / removed tool module | mitigate | `with` else `_ -> :fallback` (`preview.ex:82-83`) catches `{:error, :unknown_tool}`; `resolve_title/1` falls to `humanize_tool_ref/1` — never emits raw module atom. | closed |
| T-14-04 (T-idem) | Tampering | `derive_idempotency_key/4` dedupe semantics | mitigate | Canonical map = `tool_ref, actor_id, account_id, input, dedupe_token` only (`governance.ex:109-119`); `conversation_id` count == **0** in canonical map. D-08 exclusion comment line 109. | closed |
| T-14-05 | Info Disclosure (PII) | `input_rows/1` masking choke point (D-22) | mitigate | `tool_proposal_presenter.ex:173-183`: `sensitive_field?/1` masks password/token/secret/key/credential; `normalize_input_value/1` returns "Unsupported value" for nested/complex types. Never iterates arbitrary snapshot maps. | closed |
| T-14-06 | Info Disclosure / brand | raw Elixir terms via `reason_label`/`policy_explanation` | mitigate | `reason_label/1` (`tool_proposal_presenter.ex:138-156`) humanizes nil/`{:missing_scopes,_}`/atom/string/tuple with no `inspect`; `inspect` count == **0** in presenter. `policy_explanation/1` (line 214) emits a calm sentence. | closed |
| T-14-02-01 (T-pii) | Info Disclosure (PII) | inline rendering of snapshot maps | mitigate | `conversation_live.ex:855` `input_rows/1` is sole inline path; raw `input_snapshot` only inside `<details>` (lines 970-973). Template iterates `@input_rows` only. | closed |
| T-14-02-02 | Info Disclosure / brand | raw Elixir terms / module atoms in DOM | mitigate | Headline from `Preview.render/1` fallback chain (`conversation_live.ex:894-907`) — never raw module atom; reasons via `reason_label/1` (206/209/212/872); policy via `policy_explanation/1` (857). | closed |
| T-14-02-03 | Tampering / phishing affordance | misleading "Approve" affordance before Phase 15 | mitigate | `governed_action_card/1` (845-1041): `phx-click` count == **0**; footer slot (1036-1038) empty (comment only). No approve/reject/defer button. | closed |
| T-14-02-04 (XSS) | Tampering | host `preview/1` prose rendered to DOM | mitigate | `raw(` count == **0** in `conversation_live.ex`; all prose via standard HEEx `<%= … %>` auto-escaping. No `raw/1` on host strings. | closed |
| T-14-03-01 (T-pii) | Info Disclosure / brand | `inspect(reason)` in `failure_reason_message/1` reaching operator | mitigate | All three clauses (`conversation_live.ex:205-212`) call `ToolProposalPresenter.reason_label(reason)`; `inspect(` count == **0** in the function (D-14). | closed |
| T-14-03-02 | Tampering | `conversation_id` sourced from client params | mitigate | `conversation_live.ex:181` `Map.put(context, :conversation_id, socket.assigns.conversation.id)` — server-trusted, not request params. | closed |
| T-14-03-03 (T-pii) | Info Disclosure | rail rendering of proposals incl. blocked ones | mitigate | Rail (`conversation_live.ex:582-589`) iterates `@governed_actions` exclusively via `<.governed_action_card />`; no direct snapshot-field reference. Blocked proposals shown through the masking path (Support-Truth Gate). | closed |
| T-14-W0-SC / T-14-SC (W1–W3) | Tampering | mix / external installs | accept | Phase 14 installs no packages (RESEARCH Package Legitimacy Audit: Not applicable); no new deps. See Accepted Risks Log. | closed |
| T-14-03-04 | Denial of Service | unbounded rail list | accept | Bounded per-conversation, indexed `[conversation_id, inserted_at]` query (`governance.ex:407-411`); `stream(` count == **0** (D-02). Re-evaluate at Phase 16. See Accepted Risks Log. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-14-01 | T-14-W0-SC / T-14-SC (Waves 1–3) | Phase 14 adds no new dependencies; no `[ASSUMED]`/`[SUS]` packages → no install checkpoint required. | gsd-secure-phase (owner ratified) | 2026-05-24 |
| AR-14-02 | T-14-03-04 | Rail list is bounded per-conversation and loaded via the indexed `[conversation_id, inserted_at]` query; Phase 14 has no status churn (no streams, D-02). Re-evaluate at Phase 16 when execution events flow. | gsd-secure-phase (owner ratified) | 2026-05-24 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-24 | 17 | 17 | 0 | gsd-security-auditor (verify-mitigations mode; register authored at plan time) |

---

## Audit Notes

- `inspect/1` appears in `governed_action_card/1` (`conversation_live.ex` lines 972, 994, 1019) but only inside `<details>` expander elements for opt-in raw snapshot views — compliant with D-22. Inline operator-visible paths never use `inspect/1`.
- `inspect(@tool)` in `tool_renderer/1` (lines 692, 702, 714) is pre-Phase-14 behavior for tool-module identification in form params; out of scope of the Phase 14 register.
- Pre-existing baseline (per STATE.md / Phase 14 SUMMARYs): 1 failing test unrelated to Phase 14, plus `Cairnloop.Repo` Postgrex boot noise where the workspace DB is unavailable. Not a Phase 14 regression.
- `mix compile --warnings-as-errors` exits 0 (verified during audit).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-24
