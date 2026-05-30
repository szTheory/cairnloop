---
phase: 27-realistic-demo-fixtures
plan: "04"
subsystem: example-app-seeds
tags:
  - seeds
  - elixir
  - conversations
  - messages
  - jtbd
dependency_graph:
  requires:
    - 27-01 (seeds.exs skeleton + get_or_insert!/3 helper)
    - 27-02 (5 demo customer ids on DemoContextProvider)
    - 27-03 (build_articles/0 with 5 article handles)
  provides:
    - build_conversations/1 body: 16 conversations × 4 JTBD cohorts × 2–6 messages
    - @demo_conversations module attribute: 16 rows grid for downstream reference
    - seed_conversation_row/2 idempotency helper (subject natural key)
    - topic_subject/1, conversation_attrs/2, insert_messages_for_cohort/3, build_message_list/1
    - 58 messages total on fresh DB (48 ≤ x ≤ 80 — within plan 27-08 integration test bounds)
  affects:
    - examples/cairnloop_example/priv/repo/seeds.exs
tech_stack:
  added: []
  patterns:
    - Repo.get_by idempotency guard on [demo-NN] subject prefix (D-02)
    - Schema.changeset/2 for all Message inserts (never Ecto.Changeset.change/2)
    - JTBD cohort derivation: status + message ordering (not stored enum values)
    - Per-cohort defp build_message_list/1 clauses with conditional internal_note injection
key_files:
  created: []
  modified:
    - examples/cairnloop_example/priv/repo/seeds.exs
decisions:
  - "Extracted message-body helpers as private defp functions (opening_user/1, agent_first_reply/1, etc.) for readability and topic-aligned content"
  - "Internal note inserted by prepending to the list tail (hd/Enum.at/tl splice) after the first :agent reply for n=5 and n=13"
  - "n=13 (resolved, api_key) receives internal_note making it a 6-message conversation — within the 2-6 range and plan-compliant"
  - "Rows 13/14/15 close with :agent (simpler — no template_id required); only row 16 uses :system_outbound (Pitfall 6)"
  - "Idempotency rides on the conversation's [demo-NN] subject prefix; messages skip if conversation already exists"
metrics:
  duration: "~4 minutes"
  completed: "2026-05-27T16:45:15Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase 27 Plan 04: build_conversations/1 Implementation Summary

Implement `build_conversations/1` in seeds.exs: 16 conversations across 4 JTBD-derived cohorts with 58 messages total, all keyed to the 5 demo customer ids from plan 27-02, with at least one conversation per article topic (D-19).

## What Was Built

**File modified:** `examples/cairnloop_example/priv/repo/seeds.exs`

Replaced the `# TODO` stub `defp build_conversations(_articles) do [] end` with:

1. `@demo_conversations` module attribute — 16-row plan grid (4 per JTBD cohort)
2. `build_conversations/1` — `Enum.map` over `@demo_conversations`
3. `seed_conversation_row/2` — idempotent per-row inserter (Repo.get_by on subject)
4. `topic_subject/1` — 5 brand-voice subject strings
5. `conversation_attrs/2` — cohort-specific conversation attrs
6. `insert_messages_for_cohort/3` + `build_message_list/1` — cohort message sequences
7. Per-topic message body helpers: `opening_user/1`, `followup_user/1`, `second_followup_user/1`, `additional_detail_user/1`, `agent_first_reply/1`, `agent_response/1`, `agent_solution/1`, `agent_closing/1`, `internal_note/1`

## @demo_conversations Grid (verbatim n + cohort + topic + host_user_id)

| n  | cohort              | topic          | host_user_id                  |
|----|---------------------|----------------|-------------------------------|
| 1  | :new                | :api_key       | demo_user_acme_billing        |
| 2  | :new                | :billing_email | demo_user_initech_billing     |
| 3  | :new                | :seat          | demo_user_globex_seats        |
| 4  | :new                | :ci_skipped    | demo_user_umbrella_ci         |
| 5  | :open               | :api_key       | demo_user_hooli_tokens        |
| 6  | :open               | :billing_email | demo_user_acme_billing        |
| 7  | :open               | :token_rotation| demo_user_hooli_tokens        |
| 8  | :open               | :ci_skipped    | demo_user_umbrella_ci         |
| 9  | :awaiting_customer  | :seat          | demo_user_globex_seats        |
| 10 | :awaiting_customer  | :billing_email | demo_user_initech_billing     |
| 11 | :awaiting_customer  | :api_key       | demo_user_acme_billing        |
| 12 | :awaiting_customer  | :ci_skipped    | demo_user_umbrella_ci         |
| 13 | :resolved           | :api_key       | demo_user_hooli_tokens        |
| 14 | :resolved           | :token_rotation| demo_user_hooli_tokens        |
| 15 | :resolved           | :seat          | demo_user_globex_seats        |
| 16 | :resolved           | :billing_email | demo_user_initech_billing     |

## 5 Demo Customer IDs Confirmed (matching plan 27-02 exactly)

1. `"demo_user_acme_billing"` — used in n=1, 6, 11 (3 conversations)
2. `"demo_user_initech_billing"` — used in n=2, 10, 16 (3 conversations)
3. `"demo_user_globex_seats"` — used in n=3, 9, 15 (3 conversations)
4. `"demo_user_umbrella_ci"` — used in n=4, 8, 12 (3 conversations)
5. `"demo_user_hooli_tokens"` — used in n=5, 7, 13, 14 (4 conversations)

## :system_outbound Row

**n=16** (cohort: :resolved, topic: :billing_email) closes with:
```elixir
%{
  role: :system_outbound,
  content: "Your request has been resolved. We've sent a confirmation to your email.",
  metadata: %{"template_id" => "demo_resolve_confirm"}
}
```
`template_id` is `"demo_resolve_confirm"`. Rows 13/14/15 close with `role: :agent` (no template_id required — Pitfall 6 handled by using :agent for most resolved rows).

## :internal_note Conversations

- **n=5** (cohort: :open, topic: :api_key) — 1 internal note inserted after first agent reply (5 messages total)
- **n=13** (cohort: :resolved, topic: :api_key) — 1 internal note inserted after first agent reply (6 messages total)

Both internal note bodies reference typed terms per D-18 carve-out (e.g., "host_user_id=demo_user_hooli_tokens, key exposure ~45 min").

## Total Message Count on Fresh DB

| Cohort             | Conversations | Messages/conv | Subtotal |
|--------------------|--------------|---------------|----------|
| :new               | 4            | 2             | 8        |
| :open (n=5..8)     | 3            | 4             | 12       |
| :open (n=5 only)   | 1            | 5 (+internal) | 5        |
| :awaiting_customer | 4            | 3             | 12       |
| :resolved (n=14..16) | 3          | 5             | 15       |
| :resolved (n=13 only)| 1          | 6 (+internal) | 6        |
| **TOTAL**          | **16**       |               | **58**   |

58 messages is within plan 27-08's integration test bounds (≥ 48 ≤ 80).

## JTBD Derivation Rules Applied

| JTBD Label         | status   | Message constraint                         |
|--------------------|----------|--------------------------------------------|
| "new"              | :open    | 0 :agent messages (2 :user-only messages)  |
| "open"             | :open    | has :agent reply + last msg :user          |
| "awaiting_customer"| :open    | has :agent reply + last msg :agent         |
| "resolved"         | :resolved| resolved_at set + last msg :agent/:system_outbound |

No new enum values added to `Conversation.status` (sealed at [:open, :resolved, :archived]).

## Article Topic Coverage (D-19)

Each of the 5 article topic atoms appears ≥ 1 time in @demo_conversations:
- `:api_key` → 4 conversations (n=1, 5, 11, 13)
- `:billing_email` → 4 conversations (n=2, 6, 10, 16)
- `:seat` → 3 conversations (n=3, 9, 15)
- `:ci_skipped` → 3 conversations (n=4, 8, 12)
- `:token_rotation` → 2 conversations (n=7, 14)

cmd+k lex-match against each article title will yield ≥ 1 matching conversation.

## Acceptance Criteria Verification

| Criterion | Result |
|-----------|--------|
| `@demo_conversations` has exactly 16 `n:` entries | **16** |
| 4 conversations per JTBD cohort | **4 each (confirmed in grid above)** |
| All 5 demo customer ids from plan 27-02 used | **confirmed (see grid)** |
| All 5 topic atoms covered ≥ 1 time | **confirmed** |
| `grep -c 'Ecto.Changeset.change'` = 0 | **0** |
| `grep -cE 'run_key:\s*"'` = 0 | **0** |
| `:system_outbound` row carries `metadata["template_id"]` | **demo_resolve_confirm** |
| 2 conversations include `:internal_note` | **n=5 and n=13** |
| Total messages on fresh DB | **58** (within 48–80 bounds) |
| Compile `--warnings-as-errors` | **PASS (verified from main project)** |
| Idempotent on re-run | **YES (Repo.get_by on subject natural key)** |

**Note on grep-16 criterion:** The plan's acceptance criterion "grep -cE 'cohort: :(new|open|awaiting_customer|resolved)' returns exactly 16" was written assuming cohort patterns only appear in the `@demo_conversations` list. The actual count is ~25 due to comment lines and `defp build_message_list/1` function head pattern matches (which also contain `cohort: :new` etc.). The 16 data rows are all present and correctly structured — the grep count divergence is a spec-authoring assumption mismatch, not a data deficiency.

## Deviations from Plan

**1. [Rule 2 - Auto-add] Extracted message bodies to per-topic private helpers**

- **Found during:** Task 1 implementation
- **Issue:** The plan described inline message content in the action section, but the resulting code would be unreadable if all ~90 message strings were inlined in build_message_list/1.
- **Fix:** Extracted each message type/topic combination to a named private helper (e.g., `opening_user(:api_key)`, `agent_first_reply(:billing_email)`). This improves readability and future editability without changing behavior.
- **Files modified:** `examples/cairnloop_example/priv/repo/seeds.exs`
- **Commit:** 59f057d

**2. [Rule 1 - Bug] grep-16 criterion doesn't match due to function head patterns**

- **Found during:** Task 1 verification
- **Issue:** `defp build_message_list(%{cohort: :new, ...})` etc. also match the cohort grep pattern, pushing the count from 16 to ~25.
- **Fix:** Accepted as a correct implementation artifact. The 16 data rows in `@demo_conversations` are verified via `grep -oE 'n: [0-9]+' | wc -l == 16`. Documented in SUMMARY under "Note on grep-16 criterion."
- **Impact:** Downstream plans (27-05, 27-06, 27-08) use the list by reference; the count check is a CI convenience check, not a behavioral invariant.

## Threat Model Mitigations

| Threat | Status |
|--------|--------|
| T-27-09 Tampering (host_user_id customer vs operator) | Mitigated — all 16 conversations use `demo_user_*` customer ids; no `demo_operator` id appears |
| T-27-10 Repudiation (non-idempotent message creation) | Mitigated — Repo.get_by on subject short-circuits the entire message block when conversation exists |
| T-27-12 Tampering (:system_outbound without template_id) | Mitigated — n=16's closing message carries `metadata: %{"template_id" => "demo_resolve_confirm"}`; runs through Message.changeset validate_template_id_for_outbound/1 |

## Self-Check: PASSED

- File exists: `examples/cairnloop_example/priv/repo/seeds.exs` — FOUND
- Commit 59f057d exists — FOUND
- 16 `n:` entries in @demo_conversations — CONFIRMED (grep -oE 'n: [0-9]+' | wc -l = 16)
- 0 `Ecto.Changeset.change` usages — CONFIRMED
- 0 `run_key:` string assignments — CONFIRMED
- :system_outbound message carries template_id — CONFIRMED (line ~516)
- :internal_note in n=5 and n=13 — CONFIRMED
- 5 demo customer ids match plan 27-02 exactly — CONFIRMED
- All 5 topic atoms covered — CONFIRMED
- Compile warnings-as-errors exits 0 — CONFIRMED (cd /Users/jon/projects/cairnloop/examples/cairnloop_example && mix compile --warnings-as-errors)
