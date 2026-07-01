---
phase: 45
slug: seed-enrichment-screenshot-regen-verification-sweep
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-26
updated: 2026-06-26
---

# Phase 45 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Revised after checker iteration 1 to match the finalized 9-task plan set.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix LiveView tests, PhoenixTest Playwright 0.14.0, Playwright 1.60.0, Node verification scripts |
| **Config file** | Root `mix.exs`, example `examples/cairnloop_example/mix.exs`, example `config/test.exs`, screenshot `examples/cairnloop_example/screenshots/package.json` |
| **Quick run command** | `cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test test/cairnloop_example/seeds_test.exs --only phase45_seed_contract` |
| **Full suite command** | `mix test && PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration && mix check && (cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test.e2e) && (cd examples/cairnloop_example/screenshots && BASE_URL=http://localhost:4000 npm run capture)` |
| **Estimated runtime** | Focused seed/source checks should be short; full sweep and screenshot regeneration run at phase close |

---

## Sampling Rate

- **After every task commit:** Run the focused command listed in the Per-Task Verification Map for the changed surface.
- **After Wave 1:** Run seed tests plus screenshot source/README checks.
- **After Wave 2:** Run exact screenshot path verification and ledger parser verification.
- **Before `/gsd:verify-work`:** Root `mix test`, root integration, `mix check`, example E2E, screenshot regeneration, structured transcript validation, and release-gate review must be green.
- **Max feedback latency:** Prefer focused checks under 120 seconds; the full sweep can exceed that and belongs at phase-close gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 45-01-01 | 01 | 1 | SEED-01 | T-45-01, T-45-03 | Seed contract includes governed states, ReviewTask states, masked MCP tokens, high-risk demo proposal, and audit empty-state sentinel absence | DB seed contract | `cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test test/cairnloop_example/seeds_test.exs --only phase45_seed_contract` | Yes | pending |
| 45-01-02 | 01 | 1 | SEED-01 | T-45-04 | High-risk demo tool remains example-app-only and performs no destructive side effect | Compile/source | `cd examples/cairnloop_example && mix compile --warnings-as-errors` | No - task creates module | pending |
| 45-01-03 | 01 | 1 | SEED-01 | T-45-01, T-45-02, T-45-03 | Facade-first seed enrichment is deterministic and re-runnable | DB seed contract | `cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test test/cairnloop_example/seeds_test.exs` | Yes | pending |
| 45-02-01 | 02 | 1 | VERIFY-01 | T-45-05, T-45-06 | Capture script forces browser/app theme and defines every operator/admin shot, including true empty-state capture | JS syntax + source assertion | `cd examples/cairnloop_example/screenshots && node --check capture.mjs && rg -n 'THEMES|colorScheme: theme\\.colorScheme|phx:theme|dataset\\.theme|06b-action-rejected|06c-action-deferred|14-audit-empty-state|phase45-empty-audit-filter|No audit events found' capture.mjs` | Yes | pending |
| 45-02-02 | 02 | 1 | VERIFY-01 | T-45-06, T-45-SC | README preserves non-gating evidence posture and dual-theme paths | Source/doc assertion | `rg -n 'guides/assets/light|guides/assets/dark|capture-only|non-gating|BASE_URL=http://localhost:4000 npm run capture|behavior' examples/cairnloop_example/screenshots/README.md` | Yes | pending |
| 45-03-01 | 03 | 2 | VERIFY-01 | T-45-09, T-45-10, T-45-12 | Exact expected light/dark PNG path set exists with nonzero bytes, including `14-audit-empty-state.png` | Node filesystem assertion | `node -e 'const fs=require("fs"); const shots=["02-cockpit-home.png","02b-operator-inbox.png","03-conversation-workspace.png","04-approve-draft.png","05-action-pending.png","06-action-executed.png","06b-action-rejected.png","06c-action-deferred.png","07-resolved-conversation.png","08-outbound-recovery.png","09-bulk-recovery.png","10-knowledge-base.png","11-knowledge-gaps.png","11b-kb-suggestions.png","11c-kb-editor.png","12-audit-log.png","13-settings.png","14-audit-empty-state.png"]; const themes=["light","dark"]; const expected=themes.flatMap(t=>shots.map(s=>`guides/assets/${t}/${s}`)).sort(); const missing=expected.filter(p=>!fs.existsSync(p)||fs.statSync(p).size===0); const actual=themes.flatMap(t=>fs.existsSync(`guides/assets/${t}`)?fs.readdirSync(`guides/assets/${t}`).filter(f=>f.endsWith(".png")).map(f=>`guides/assets/${t}/${f}`):[]).sort(); const extra=actual.filter(p=>!expected.includes(p)); if(missing.length||extra.length){ console.error(JSON.stringify({missing,extra},null,2)); process.exit(1); }'` | No - task creates screenshots | pending |
| 45-03-02 | 03 | 2 | VERIFY-01 | T-45-10, T-45-11 | Ledger has exact rows, PASS-only results, expected paths, and happy/empty/error/dense/boundary category coverage | Node Markdown parser | `node -e 'const fs=require("fs"); const path=".planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VISUAL-ACCEPTANCE.md"; const md=fs.readFileSync(path,"utf8"); const shots=["02-cockpit-home.png","02b-operator-inbox.png","03-conversation-workspace.png","04-approve-draft.png","05-action-pending.png","06-action-executed.png","06b-action-rejected.png","06c-action-deferred.png","07-resolved-conversation.png","08-outbound-recovery.png","09-bulk-recovery.png","10-knowledge-base.png","11-knowledge-gaps.png","11b-kb-suggestions.png","11c-kb-editor.png","12-audit-log.png","13-settings.png","14-audit-empty-state.png"]; const expected=["light","dark"].flatMap(t=>shots.map(s=>`guides/assets/${t}/${s}`)); const missing=expected.filter(p=>(md.match(new RegExp(p.replace(/[.*+?^${}()|[\\]\\\\]/g,"\\\\$&"),"g"))||[]).length!==1); const bad=/\\|\\s*FAIL\\s*\\|/i.test(md); const categories=["happy","empty","error","dense","boundary"].filter(c=>!new RegExp(`\\\\|[^\\\\n]*\\\\|\\\\s*${c}\\\\s*\\\\|`,"i").test(md)); const passRows=(md.match(/\\|[^\\n]*\\|\\s*PASS\\s*\\|/g)||[]).length; if(missing.length||bad||categories.length||passRows!==36||!/No audit events found/.test(md)){ console.error(JSON.stringify({missing,bad,categories,passRows},null,2)); process.exit(1); }'` | No - task creates ledger | pending |
| 45-04-01 | 04 | 3 | VERIFY-02 | T-45-13, T-45-15 | Final green claim is backed by structured command transcripts with exit status 0 for every full-sweep lane | Node Markdown parser | `node -e 'const fs=require("fs"); const md=fs.readFileSync(".planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VERIFICATION.md","utf8"); const required=["root mix test","root mix test.integration","root mix check","example mix test.e2e","screenshot npm run capture"]; const missing=required.filter(name=>!new RegExp(`\\\\|\\\\s*${name.replace(/[.*+?^${}()|[\\\\]\\\\\\\\]/g,"\\\\\\\\$&")}\\\\s*\\\\|[^\\\\n]*\\\\|\\\\s*0\\\\s*\\\\|`,"i").test(md)); if(missing.length||!/Command Transcripts/.test(md)||!/45-VISUAL-ACCEPTANCE/.test(md)||!/PASS/.test(md)){ console.error(JSON.stringify({missing},null,2)); process.exit(1); }'` | No - task creates report | pending |
| 45-04-02 | 04 | 3 | VERIFY-02 | T-45-14, T-45-15 | Source audit closes every requirement/decision, release gate remains canonical, and no human UAT checkpoint exists | Source assertion | `rg -n 'Source Audit Closeout|SEED-01|VERIFY-01|VERIFY-02|D-01|D-15|Release Gate Review|No Human UAT Outstanding|COVERED' .planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VERIFICATION.md && rg -n 'release_gate|integration|quality|e2e' .github/workflows/ci.yml && ! rg -n '(^|[^[:alnum:]_])checkpoint:[-]human-verify([^[:alnum:]_]|$)' .planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep` | No - task creates report | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [x] Every finalized task has an automated verification command.
- [x] The screenshot matrix has an exact expected path set: 18 filenames across light and dark themes.
- [x] Empty-state proof is concrete: Plan 45-01 seed tests reserve the unmatched audit sentinel, Plan 45-02 captures `14-audit-empty-state.png`, Plan 45-03 ledgers and parses it.
- [x] Visual acceptance ledger verification checks exact paths, PASS-only rows, no FAIL rows, and happy/empty/error/dense/boundary category coverage.
- [x] Final sweep verification validates structured command transcripts with required command names and exit status `0`.

---

## Manual-Only Verifications

None. Phase 45 follows the project-level "automate the world / 0 human UAT" decision. Screenshots and traces are evidence/debug artifacts; behavior remains gated by automated ExUnit, integration, E2E, parser, and source checks.

---

## Validation Sign-Off

- [x] All 9 tasks have automated verify commands.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Focused feedback latency target is under 120 seconds where practical.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** ready for plan checker
