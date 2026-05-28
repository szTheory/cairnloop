# Phase 30: KB Editorial Polish + T-10-09 / T-10-11 Closure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 30-kb-editorial-polish-t-10-09-t-10-11-closure
**Areas discussed:** HandoffToken gate design, Gap sidebar data source, Index direct-Repo fix

---

## HandoffToken gate design (T-10-09 + T-10-11 closure)

### Question 1 — Where does the gate live?

| Option | Description | Selected |
|--------|-------------|----------|
| Signed token + DB write | `open_for_manual_edit` writes `manual_edit_opened_at` to DB (T-10-09 audit trail) AND includes it in signed token; `verify!/2` rejects tokens without it (T-10-11 closure) | ✓ |
| DB check only | DB write at open time; Editor checks `suggestion.manual_edit_opened_at` non-nil after loading. Extra DB read. | |
| Token only | Include in signed token; no DB write at open time (field set later on draft save). | |

**User's choice:** Signed token + DB write (recommended option)
**Notes:** Double-layer gate satisfies both threat descriptions: T-10-09 wants auditable DB record; T-10-11 wants Editor to require deliberate server-side handoff state beyond bare URL params.

### Question 2 — How to include in signed token?

| Option | Description | Selected |
|--------|-------------|----------|
| Keyword opts on sign | `sign(..., opts \\ [])` — `open_for_manual_edit` passes `[manual_edit_opened_at: ...]`. Additive, doesn't break existing call sites. | ✓ |
| New sign/5 positional | Explicit but breaks existing 4-arg call sites; requires updating multiple callers. | |

**User's choice:** Keyword opts (recommended)
**Notes:** Elixir convention for optional parameters; existing call sites work unchanged.

### Question 3 — Domain function name?

| Option | Description | Selected |
|--------|-------------|----------|
| record_editor_handoff/2 | `knowledge_automation().record_editor_handoff(suggestion_id, scope_filters)`. Clear intent: handoff initiation distinct from draft-save. | ✓ |
| mark_suggestion_opened/2 | Same mechanics, less specific name. | |
| You decide | Any name that clearly distinguishes handoff-open from draft-save. | |

**User's choice:** record_editor_handoff/2 (recommended)

### Question 4 — How to access decoded payload for manual_edit_opened_at check?

Three approaches researched via subagent:

| Approach | Description | Selected |
|----------|-------------|----------|
| A: Add Token.decode/2 (decode only, no attrs match) | Additive `decode(token) :: {:ok, payload} | {:error, reason}`. Web `verify!/2` calls decode, checks marker, validates attrs against decoded map. Canonical Phoenix.Token / Guardian / Joken pattern. | ✓ |
| B: verify_with_timestamp/2 in domain | New function in domain layer that bundles timestamp assertion. Couples product rule into domain. | |
| C: Include timestamp in normalize/1 (full payload match) | Caller must supply expected timestamp at verify time — IDOR footgun if caller reads from URL params. | |

**User's choice:** Research-backed — Approach A (Token.decode) confirmed as canonical pattern
**Notes:** Research found Approach C has a latent IDOR: a caller that reads `params["manual_edit_opened_at"]` to satisfy the expected-attrs requirement effectively compares the token's own value against itself (`nil == nil` passes). Approach B couples a product rule into the domain layer. Approach A keeps domain policy-agnostic; web wrapper owns semantic assertions.

---

## Gap sidebar data source (KB-03)

### Question 1 — How does Editor discover GapCandidate?

Two approaches researched via subagent:

| Approach | Description | Selected |
|----------|-------------|----------|
| A: Derive from suggestion.entrypoint_id | `suggestion.entrypoint_type == :gap_candidate && suggestion.entrypoint_id` IS the `gap_candidate_id`. No token changes. Domain model is single source of truth. | ✓ |
| B: Explicit gap_candidate_id in token + URL | Add field to signed token and URL. Duplicates data already on the suggestion record. Blends attestation with data transport. | |

**User's choice:** Research-backed — Approach A confirmed
**Notes:** UI-SPEC §KB-03 line 339 ("EditorHandoff.sign/4 gains a gap_candidate_id optional field") was written before the existing schema relationship was recognized. Approach A is correct — `ArticleSuggestion.entrypoint_id` when `entrypoint_type == :gap_candidate` is the canonical `gap_candidate_id`. Research found this is consistent with how `hydrate_gap_candidate_request/2` and `entrypoint_id_for/2` already use this relationship internally.

---

## Index direct-Repo fix (KB-01, KB-02 arch)

### Question 1 — Fix or leave as tech debt?

| Option | Description | Selected |
|--------|-------------|----------|
| Fix in Phase 30 | Add `KnowledgeBase.list_articles(opts \\ [])`. Arch-invariant compliant before Phase 31 traverses Index. One function, one call-site change. | ✓ |
| Leave as pre-existing tech debt | Note violation in CONTEXT.md for vM015. Strictly additive Phase 30. | |

**User's choice:** Fix in Phase 30 (recommended)

### Question 2 — list_articles/0 or list_articles/1 with opts?

Two approaches researched via subagent:

| Option | Description | Selected |
|--------|-------------|----------|
| list_articles(opts \\ []) | Consistent with all 6 KnowledgeAutomation list functions. No arity-breaking change when Article gains tenant fields. opts reserved, currently ignored for non-status keys. | ✓ |
| list_articles/0 global | Simpler but causes arity-proliferation and breaking change when tenant isolation lands. Diverges from facade patterns. | |

**User's choice:** Research-backed — list_articles/1 with opts \\ [] confirmed
**Notes:** Research: `list_articles/0` creates a breaking arity change when Article gains tenant fields (in Elixir, `/0` and `/1` are different functions). Six parallel KnowledgeAutomation functions already use `opts \\ []`. Oban's `all_enqueued(opts \\ [])` and Ecto.Multi demonstrate this is standard Elixir library practice. Include `:status` filter support now as it provides immediate utility for the Index listing.

---

## Claude's Discretion

The following decisions were made by Claude without user input (per CLAUDE.md shift-left policy):

1. **Nav shell module location:** `Cairnloop.Web.KnowledgeBaseLive.NavComponent` with `def kb_nav/1` — dedicated module over inline defp, cleaner import/alias story for four LiveViews.
2. **Blank article title for KB-02:** `"Untitled article"` — satisfies `Article.changeset/2` `validate_required([:title])`, simple, operator-editable.
3. **Copy ownership for KB-04:** Update `ReviewTaskPresenter.action_label/2` for 3-variant copy — keep presenter-first pattern per brand book §5.5.
4. **get_gap_candidate/2 non-bang:** Wrap or add soft variant — deleted gap gracefully degrades to nil sidebar rather than 500.
5. **Double-decode avoided:** Web `verify!/2` uses the payload already decoded by `Token.decode/1` for the attrs-match assertion rather than calling `Token.verify/2` a second time (avoids double `Plug.Crypto.verify`).

## Deferred Ideas

- T-10-10 / T-10-12 / T-10-13 (domain-layer security threats in `knowledge_automation.ex`) — deferred to vM015 per pre-existing assessment decision.
- Article tenant isolation (`host_user_id` / `tenant_scope` fields) — opts reserved in `list_articles/1` for when this lands.
