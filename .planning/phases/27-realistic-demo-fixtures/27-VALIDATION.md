---
phase: 27
slug: realistic-demo-fixtures
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
completed: 2026-05-27
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `27-RESEARCH.md` §Validation Architecture (lines 639–675).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) |
| **Config files** | `mix.exs` (library) + `examples/cairnloop_example/mix.exs` (example app) — each owns its own `test` alias |
| **Quick run command (headless)** | `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` |
| **Quick run command (integration, DB-backed)** | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` *(requires Postgres on `localhost:5433` with `cairnloop_example_test` DB)* |
| **Full suite (library)** | `mix test` |
| **Full integration suite (library)** | `mix test.integration` *(dockerized Postgres harness)* |
| **Full suite (example app)** | `cd examples/cairnloop_example && mix test` |
| **Estimated runtime** | Headless: <1 sec · Integration: 10–30 sec with Postgres available |

---

## Sampling Rate

- **After every task commit:** Run `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` *(headless, <1 sec)*
- **After every plan wave:** Run `cd examples/cairnloop_example && mix test` *(includes both the headless test and the seeds integration test; ~10–30 sec)*
- **Before `/gsd:verify-work`:** Full suite must be green — `mix test` (library) + `mix test.integration` (library) + `cd examples/cairnloop_example && mix test`. Also a manual run of `cd examples/cairnloop_example && mix setup` (or `mix ecto.reset`) to visually confirm the dashboard renders correctly in a browser — the FIX-01..FIX-04 final-visual check that no automated test can fully replace.
- **Max feedback latency:** <1 sec (headless) · <30 sec (integration)

---

## Per-Task Verification Map

> Skeleton — the planner populates concrete task rows from PLAN.md frontmatter in step 8 (`/gsd:plan-phase`) and updates `Status` columns as it executes.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 27-02-T1 | 27-02 | 1 | FIX-01 (ContextProvider) | — | `DemoContextProvider.get_context/2` returns documented shape for known + unknown actors (fail-open `{:ok, %{}}`) | unit (pure, headless) | `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` | ✅ | ✅ green |
| 27-08-T1 | 27-08 | 7 | FIX-01 (conversations) | T-27-23 | Seed produces ≥16 conversations; ≥12 :open, ≥4 :resolved; 48 ≤ messages ≤ 80 | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ✅ | ✅ ready (REPO-UNAVAILABLE in dev) |
| 27-08-T1 | 27-08 | 7 | FIX-02 (articles + revisions) | T-27-23 | Seed produces ≥5 articles, ≥6 revisions, ≥1 with `state: :archived` | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ✅ | ✅ ready (REPO-UNAVAILABLE in dev) |
| 27-08-T2 | 27-08 | 7 | FIX-02 (Oban-driven embeddings) | T-27-25 | After `Oban.drain_queue/1`, `cairnloop_chunks` table is non-empty (M008 substrate self-test) | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ✅ | ✅ ready (REPO-UNAVAILABLE in dev) |
| 27-08-T1 | 27-08 | 7 | FIX-03 | T-27-23 | Seed produces ≥3 `GapCandidate` rows with `status: :open` and ≥1 `GapCandidateMembership` each | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ✅ | ✅ ready (REPO-UNAVAILABLE in dev) |
| 27-08-T3 | 27-08 | 7 | FIX-04 | T-27-23 | Seed produces ≥1 `ArticleSuggestion status: :ready` with companion `ReviewTask {status: :pending_review}` | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ✅ | ✅ ready (REPO-UNAVAILABLE in dev) |
| 27-08-T4 | 27-08 | 7 | D-02 (idempotency) | T-27-24 | Running seeds twice is a no-op — row counts stable after second eval | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ✅ | ✅ ready (REPO-UNAVAILABLE in dev) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` — pure headless test for `DemoContextProvider.get_context/2` (covers FIX-01 ContextProvider snippets)
- [ ] `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` — DB-backed test running the seed and asserting row counts hit FIX-01..FIX-04 thresholds + `cairnloop_chunks` non-empty after Oban drain + idempotency
- No additional framework install: ExUnit is already available; `CairnloopExample.DataCase` already exists at `examples/cairnloop_example/test/support/data_case.ex`
- Seed must be invokable from a test context — either via `Code.eval_file("priv/repo/seeds.exs")` (works because the test owns the sandboxed DB connection), or via a small `CairnloopExample.SeedDemo.run/0` module called by both `seeds.exs` and the integration test. **Planner picks the simpler path.**

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Brand voice on seeded conversation/article copy | CLAUDE.md C-08 + `prompts/cairnloop_brand_book.md` §5/§5.5/§7.5 | Tone is editorial — calm/fail-closed/reason-forward; no raw Elixir atoms or raw JSON in customer- or operator-visible copy. No deterministic check. | Executor self-reviews each seeded subject/body/article paragraph against the brand book §5.5 register before committing. |
| Warnings-clean seed script | D-21 | `mix compile --warnings-as-errors` does not cover `.exs` scripts; the executor must visually scan compile output for `seeds.exs`. | `cd examples/cairnloop_example && mix run --no-start priv/repo/seeds.exs` (start-less compile-check; flags syntax/warning issues before DB ops). |
| Adopter-visible dashboard on first boot | FIX-01..FIX-04 *(integration)* | Final UI verification needs human eyes to confirm the inbox, KB index, gap queue, and SuggestionReview LiveView render the seeded rows correctly. | `cd examples/cairnloop_example && mix setup` (or `mix ecto.reset`) → `mix phx.server` → open `/support`. Confirm: ≥12 conversations across 4 cohorts, ≥5 articles with multi-revision tab, ≥3 gaps in queue, ≥1 suggestion in review. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (both test files in `examples/cairnloop_example/test/`)
- [ ] No watch-mode flags
- [ ] Feedback latency <30s (integration), <1s (headless)
- [ ] `nyquist_compliant: true` set in frontmatter once Wave 0 tests exist and the per-task map is populated by the planner

**Approval:** pending
