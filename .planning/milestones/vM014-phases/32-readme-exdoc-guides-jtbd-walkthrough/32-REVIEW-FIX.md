---
phase: 32-readme-exdoc-guides-jtbd-walkthrough
fixed_at: 2026-05-28T00:00:00Z
review_path: .planning/phases/32-readme-exdoc-guides-jtbd-walkthrough/32-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 32: Code Review Fix Report

**Fixed at:** 2026-05-28T00:00:00Z
**Source review:** .planning/phases/32-readme-exdoc-guides-jtbd-walkthrough/32-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: Quickstart Router Snippet Raises `ArgumentError` at Compile Time

**Files modified:** `guides/01-quickstart.md`
**Commit:** 60ba3da
**Applied fix:** Changed `cairnloop_dashboard("/", host_user_id: "demo_operator")` to
`cairnloop_dashboard("/", session: %{"host_user_id" => "demo_operator"})`. The `host_user_id:`
keyword was being passed directly as a `live_session` option, which Phoenix LiveView
rejects at compile time. Wrapping it in `session: %{...}` is the correct form.

---

### CR-02: Install Flow Silently Skips 15 Library Migrations

**Files modified:** `guides/01-quickstart.md`
**Commit:** c237f71
**Applied fix:** Added a new "Run migrations" subsection after the Igniter installer
instructions. The section shows the two-command pattern (`mix ecto.migrate` followed by
`mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations`) and explains why
both are necessary. Also includes a tip showing how to wire both into the `ecto.setup` mix
alias.

---

### WR-01: `docker-compose.yml` Claimed to Be in Example App but Lives at Repo Root

**Files modified:** `guides/01-quickstart.md`
**Commit:** c57bc44
**Applied fix:** Changed "the example app ships a `docker-compose.yml`" to "the repository
ships a `docker-compose.yml` at the repo root. From the repo root run:" — accurately
attributing the file location so readers in `examples/cairnloop_example/` are not
confused.

---

### WR-02: CHANGELOG.md Missing Keep-a-Changelog Link Reference Definitions

**Files modified:** `CHANGELOG.md`
**Commit:** a39e2d6
**Applied fix:** Appended two link reference definitions at the end of the file:
`[Unreleased]: https://github.com/szTheory/cairnloop/compare/v0.1.0...HEAD` and
`[0.1.0]: https://github.com/szTheory/cairnloop/releases/tag/v0.1.0`. These allow the
`[Unreleased]` and `[0.1.0]` section headers to render as proper hyperlinks in HexDocs
and GitHub.

---

### WR-03: Quickstart Boot Section Omits Working Directory Context

**Files modified:** `guides/01-quickstart.md`
**Commit:** c57bc44 (committed alongside WR-01 in the same atomic fix)
**Applied fix:** Added `cd examples/cairnloop_example` as the first command in the Boot
section bash block, and updated the introductory sentence to "The commands below are for
the example app. Switch into it first, then set up the database and start the server:".

---

### WR-04: Host Integration Guide Overstates Oban Guarantee for `on_sla_breach`

**Files modified:** `guides/03-host-integration.md`
**Commit:** 18529aa
**Applied fix:** Replaced "Cairnloop calls each callback asynchronously via Oban, ensuring
reliable retries and data consistency." with accurate prose: "Cairnloop calls these
callbacks from within Oban workers — `on_conversation_resolved/2` and
`on_outbound_triggered/2` each have a dedicated Oban worker, while `on_sla_breach/3` is
called directly within the SLA countdown worker. Raising in any callback retries the
enclosing Oban job." This correctly describes `on_sla_breach/3` as a direct synchronous
call inside `CheckSLA`'s `perform/1`, not a separately-dispatched worker.

---

## Compile Result

`mix compile --warnings-as-errors` passed with exit code 0 and no output (clean build,
no warnings). All documentation-only changes — no Elixir source was modified.

---

_Fixed: 2026-05-28T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
