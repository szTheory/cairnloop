---
phase: 40-drift-remediation-brand-token-gate-hardening
verified: 2026-06-04T00:00:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
requirements:
  DRIFT-01: PASS
  DRIFT-02: PASS
  GATE-01: PASS
  GATE-02: PASS
deviations_assessed:
  - subject: ".credo.exs requires: wiring dropped to []"
    plan_specified: 'requires: ["lib/cairnloop/credo_checks/no_hardcoded_color.ex"]'
    orchestrator_did: "requires: [] — check wired via enabled: list only"
    verdict: ACCEPTED
    rationale: >
      GATE-02's GOAL is a working advisory Credo check that stays warnings-clean.
      The literal requires: wiring was a MEANS, not the goal — and a self-defeating
      one: the check module lives under lib/ (compiled into the app beam, already on
      Credo's code path), so requires: re-loaded it via Code.require_file and emitted
      a "redefining module" warning on every mix credo run (research pitfall #4),
      contradicting CLAUDE.md's warnings-clean mandate. Verified independently: with
      requires: [] the check STILL fires advisory [W] on a hardcoded hex probe in a
      web render file, AND no "redefining module" warning appears on mix credo. The
      goal is fully met; the dropped literal wiring was the correct shift-left call.
---

# Phase 40: Drift Remediation + Brand-Token Gate Hardening — Verification Report

**Phase Goal:** Remediate off-palette hardcoded hex/rgba in `conversation_live.ex` +
`search_modal_component.ex` to brand tokens + shared primitives (DRIFT-01, DRIFT-02), and harden the
brand-token ExUnit gate to catch inline hex / raw rgba/hsl / helper-returned hex with an auditable
`# cl-allow-color` allowlist, plus an advisory Credo check (GATE-01, GATE-02).

**Verified:** 2026-06-04
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `conversation_live.ex` contains zero off-palette hex/rgba/hsl | ✓ VERIFIED | `grep -nE '#[0-9a-fA-F]{3,6}\|rgba\(\|hsl\('` → exit 1, no matches |
| 2 | `search_modal_component.ex` contains zero off-palette hex/rgba/hsl | ✓ VERIFIED | same grep → exit 1, no matches |
| 3 | Approval footer uses cl_button (primary/danger/default) + ≥2 .cl-textarea | ✓ VERIFIED | 7 `<.cl_button`; footer lines 1074-1075 (primary, multiline), 1091 (danger), 1103 (default); 2× `class="cl-textarea"`; phx events `approve_action`/`reject_action`/`defer_action` preserved |
| 4 | Search source/trust badges render via cl_chip success\|info | ✓ VERIFIED | 4 `<.cl_chip variant={source_chip_variant(...)}` / `{trust_chip_variant(...)}` call sites (131,132,163,164); helper clauses return "success"/"info"/"neutral" (615-621) — the D-01/RESEARCH §F gap-#4 sanctioned presenter-clause form |
| 5 | rgba badge helpers `source_badge_style`/`trust_badge_style` deleted | ✓ VERIFIED | `grep -c` → 0 |
| 6 | `priv/static/cairnloop.css` untouched (D-01) | ✓ VERIFIED | `git diff 921efb3..HEAD -- priv/static/cairnloop.css` → empty |
| 7 | Hardened ExUnit gate fails on inline hex / raw rgba/hsl / helper hex; allowlist suppresses; passes on token/anchor/interpolation | ✓ VERIFIED | `mix test ...brand_token_gate_test.exs` → exit 0, 3 tests 0 failures; live negative probe (hex injected into real web file) → test FAILS 1 failure naming file:line; `# cl-allow-color` prev-line sentinel → 0 failures |
| 8 | Advisory Credo check exists, fires on render-file hex, stays advisory | ✓ VERIFIED | module `use Credo.Check, base_priority: :low`; no `exit_status`; probe → `[W]` advisory on `color: #4A6238;` with correct message + line; no redefine warning on `mix credo` |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/web/conversation_live.ex` | On-palette rail + primitive footer | ✓ VERIFIED | hex/rgba-free; footer = cl_button + cl-textarea + cl-stack/cl-row utilities + token-valued inline |
| `lib/cairnloop/web/search_modal_component.ex` | On-palette modal, chip badges | ✓ VERIFIED | hex/rgba-free; cl_chip badges; rgba helpers deleted; result_row_style token-valued |
| `test/cairnloop/web/brand_token_gate_test.exs` | Hardened gate + allowlist + fixtures | ✓ VERIFIED | 3 tests; `@hex_color`+`@func_color` patterns; interpolation-strip + comment-skip + `# cl-allow-color` line/prev-line suppression; real-file scan asserts violations == [] |
| `lib/cairnloop/credo_checks/no_hardcoded_color.ex` | Advisory dev-time check | ✓ VERIFIED | `use Credo.Check, base_priority: :low`; mirrors gate patterns; `render_file?` scope guard; no failing exit_status |
| `.credo.exs` | Custom-check wiring | ✓ VERIFIED (with assessed deviation) | check wired via `enabled:` `{...NoHardcodedColor, [priority: :low]}`; `requires: []` (deviation — see below); inline rationale comment present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| approve/reject/defer footer | cl_button / .cl-textarea | Phoenix.Component calls | ✓ WIRED | variants primary/danger/default + 2× cl-textarea, events preserved |
| source/trust badge sites | cl_chip variant | helper-clause presenter | ✓ WIRED | 4 cl_chip calls via source_chip_variant/trust_chip_variant |
| `.credo.exs` → check module | Credo load path | `enabled:` list (NOT `requires:`) | ✓ WIRED (deviation accepted) | check loaded via app beam (lives under lib/); fires advisory; requires: dropped to avoid redefine warning |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build warnings-clean | `mix compile --warnings-as-errors` | exit 0 | ✓ PASS |
| Hardened gate green on clean tree | `mix test test/cairnloop/web/brand_token_gate_test.exs` | exit 0, 3 tests 0 fail | ✓ PASS |
| Gate FAILS on real injected hex violation | inject `style="color:#4A6238"` into a web .ex, run gate | 1 failure, names file:line | ✓ PASS |
| Allowlist suppresses on real file | add `# cl-allow-color` prev-line, run gate | 0 failures | ✓ PASS |
| Credo check fires advisory on render-file hex | `mix credo <probe>` | `[W]` Hardcoded color literal at probe:3 | ✓ PASS |
| No "redefining module" warning | `mix credo` grep redefine | empty | ✓ PASS |
| Full suite test count | `mix test` | 942 tests (+1 doctest) | ✓ PASS (matches expected baseline count) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DRIFT-01 | 40-01, 40-02 | Both files zero off-palette hex; hex→token map; info/success via chip | ✓ SATISFIED | Truths 1,2,4,5 |
| DRIFT-02 | 40-01 | Footer rebuilt with cl_button + textarea class; inline-layout → .cl- utilities | ✓ SATISFIED | Truth 3; footer at 1070-1107 uses cl-stack/cl-row/token-valued inline |
| GATE-01 | 40-03 | Gate fails on inline hex / raw rgba/hsl / helper hex; `#`-anchored; allowlist; .css unscanned | ✓ SATISFIED | Truth 7; live negative+allowlist probes; globs unchanged |
| GATE-02 | 40-03 | Advisory Credo check; ExUnit gate stays CI source of truth | ✓ SATISFIED | Truth 8; requires: deviation assessed (goal met) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TBD/FIXME/XXX/HACK/PLACEHOLDER/TODO in any of the 6 modified source files |

**cl-allow-color sentinel audit:** Only 2 sentinels in `lib/cairnloop/web/` — both on moduledoc/prose
lines (`components.ex:264` drift-map comment referencing `#4A6238`/`#3F6F80`; `inbox_live.ex:42`
prose referencing `rgba(...)` deferred tokens). ZERO sentinels in the two target remediated files
(D-05 honored: no grandfathered drift). These doc sentinels are legitimate — the hardened gate now
scans all web `.ex` files including docstrings; auditable via `grep -rn cl-allow-color`.

### Incidental Files Assessment

`lib/cairnloop/web/components.ex` and `lib/cairnloop/web/inbox_live.ex` each received a single
one-line `# cl-allow-color` sentinel on a moduledoc line that mentions hex/rgba in documentation
prose. This is NOT scope creep — it is a direct consequence of GATE-01 hardening the gate to scan
all web render files. Correct, in-scope, auditable use of the allowlist.

## Baseline Failures (Excluded From Regressions)

The full `mix test` run exited non-zero with exactly the documented pre-existing failures — neither
touches the two remediated files:

| Failure | Status | Evidence it is baseline |
|---------|--------|-------------------------|
| `Cairnloop.Workers.OutboundWorkerTest` "Oban unique policy (Phase 25 D-11)" | Pre-existing | `git diff 921efb3..HEAD` of both `outbound_worker_test.exs` and `outbound_worker.ex` → empty (unchanged this phase); it is a compile-time source-string assertion unrelated to UI |
| `Cairnloop.Web.SettingsLiveTest` mount/3 order-flake | Did not surface this run | Passes in isolation per documented baseline; order-dependent flake (Test.SLA.PolicyProvider); not present in this run's failure set |

Test count = **942** (matches the expected baseline). No phase-40 regressions.

`mix credo --strict` non-zero (16) is the documented pre-existing breadcrumb_presenter_test.exs
warning — NOT from the new check (the new check is advisory `:low`, raises no failing exit_status,
confirmed by probe).

## Orchestrator Deviation Verdict (`.credo.exs requires:`)

**Plan 40-03 specified** `requires: ["lib/cairnloop/credo_checks/no_hardcoded_color.ex"]` as a
key_link/acceptance must-have. **The orchestrator dropped it to `requires: []`** (commit 24e4bb3),
wiring the check solely via the `enabled:` list.

**Verdict: ACCEPTED — GATE-02's goal is fully met.**

Independently verified:
- With `requires: []`, the check **still fires** — `mix credo` on an injected `color: #4A6238;`
  probe in a web render file emits `[W] ↘ Hardcoded color literal in render file...` at the exact
  line/function. The check is on Credo's code path because the module lives under `lib/` and is
  compiled into the app beam.
- The **"redefining module" warning is gone** — `mix credo | grep redefine` is empty. With the
  literal `requires:` wiring, the module would be re-loaded via `Code.require_file` (research
  pitfall #4), emitting a redefine warning on every run and contradicting CLAUDE.md's
  warnings-clean mandate.
- `.credo.exs` documents the deviation inline with the exact rationale.

The literal `requires:` wiring was a MEANS to the goal (a loaded, firing advisory check), not the
goal itself — and a self-defeating means. Per CLAUDE.md shift-left policy, the orchestrator made the
correct discretionary call: keep the working advisory check, drop the wiring that broke
warnings-clean. The goal "a complementary advisory Credo check flags hardcoded color in render files,
ExUnit gate stays CI source of truth" holds.

## Gaps Summary

No gaps. All 8 observable truths verified against the codebase with independent grep/test/probe
evidence (not SUMMARY claims). Both drift surfaces are hex/rgba-free; the footer is primitive-built
with preserved events; search badges use cl_chip; the rgba helpers are deleted; cairnloop.css is
untouched; the hardened gate both passes clean AND demonstrably fails on real injected violations
with a working auditable allowlist; the advisory Credo check fires without a hard exit or redefine
warning. The single orchestrator deviation (`requires: []`) was assessed and accepted — it achieves
GATE-02's goal better than the literal plan wiring would have. Build is warnings-clean; the only
test failures are documented pre-existing baselines untouched by this phase.

---

_Verified: 2026-06-04_
_Verifier: Claude (gsd-verifier)_
