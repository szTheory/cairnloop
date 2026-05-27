# Phase 26: Observability & Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `26-CONTEXT.md` — this log preserves the alternatives considered
> (and the shift-left rationale for not surfacing them as user-facing options).

**Date:** 2026-05-27
**Phase:** 26-observability-polish
**Mode:** shift-left auto-decide (per `CLAUDE.md` "Decision policy")
**Areas discussed:** Telemetry shape (OBS-01), OpenInference conformance, Audit READ surface (OBS-02), UI polish punch list, Plan-breakdown shape

---

## Telemetry shape (OBS-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Bounded-metrics only (no OI) | Add only `[:cairnloop, :outbound, :delivery, :sent / :failed]` enum-only point-in-time events. Don't touch OI. | |
| Bounded-metrics + OI trace lane (mirrors Phase 17) | Add the delivery events AND introduce `Cairnloop.Outbound.Telemetry.Traces` on the disjoint `[:cairnloop, :outbound, :trace, …]` namespace, mirroring `Cairnloop.Governance.Telemetry.Traces` from Phase 17. | ✓ |
| Replace existing bounded-metrics spans with OI traces | Tear out current trigger/bulk spans and unify under one OI lane. | |

**Auto-decided choice:** Option 2 (bounded-metrics + OI trace lane).
**Rationale:** REQ-OBS-01 literally names "OpenInference"; Phase 17 set the precedent for how Cairnloop emits OI-conformant traces on a disjoint 4-segment namespace; mirroring keeps the observability story coherent across governed actions and outbound. Option 3 was rejected outright (breaks the sealed Phase 22–25 telemetry contract). Option 1 fails the literal requirement text.
**Flagged for cheap owner veto:** D-03 in `26-CONTEXT.md` can be dropped if OI is unwanted; only bounded-metrics ships then.

---

## Delivery-side telemetry call site (within OBS-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Emit at OutboundWorker.perform/1 case arms | Point-in-time events on every terminal arm of the notifier-result case. Enum-only metadata. | ✓ |
| Wrap perform/1 in `:telemetry.span` | Emit start/stop/exception around the full perform. | |
| Rely on `Oban.Telemetry` only | Don't add Cairnloop-domain delivery events; consumers parse Oban events. | |

**Auto-decided choice:** Option 1 (point-in-time on case arms).
**Rationale:** `Oban.Telemetry` already provides job-timing spans (`[:oban, :job, …]`); duplicating with a Cairnloop span would either fight Oban's lifecycle or noise the lane. Point-in-time `:sent` / `:failed` events on the terminal arms is the Cairnloop-domain semantics ON TOP of Oban's timing — the cleanest split. Option 3 fails OBS-01's "telemetry events for … delivery" wording.

---

## Audit READ surface (OBS-02)

| Option | Description | Selected |
|--------|-------------|----------|
| No facade — host queries schema directly | `BulkEnvelope` schema is public; hosts run their own Ecto queries. | |
| Narrow `Cairnloop.Governance` facade (list + get) | `list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`, mirroring the Phase 25 cohort-read facade pattern. | ✓ |
| Facade + Cairnloop-owned `BulkOutboundHistoryLive` | Both the facade AND a first-party operator UI. | |

**Auto-decided choice:** Option 2 (facade only).
**Rationale:** D-14 (Phase 25) forbids direct Ecto queries from the web layer — that decision applies to host web layers too if they want to stay on Cairnloop's narrow contract. Option 1 breaks D-14 for any host that builds a web surface. Option 3 expands scope beyond the roadmap success criterion 3 ("polish on existing surfaces"); a host-owned admin LiveView is the layering-correct home for that UI.
**Flagged for cheap owner veto:** D-07 in `26-CONTEXT.md` can be expanded to Option 3 by adding a Wave 3 plan for `BulkOutboundHistoryLive`.

---

## UI polish punch list

| Option | Description | Selected |
|--------|-------------|----------|
| Skip polish — substrate only | Telemetry + facade only; no UI work. | |
| Minimal polish on existing surfaces | Empty states (InboxLive), modal close-button affordance, failed-bubble subhead in ConversationLive. | ✓ |
| Comprehensive UI overhaul + CSS-class extraction | All of (2) plus extracting brand-token button styles to a CSS class. | |

**Auto-decided choice:** Option 2 (minimal polish on existing surfaces).
**Rationale:** Roadmap success criterion 3 names "empty/error states and outbound affordance polish" explicitly. Option 1 fails that criterion. Option 3 expands into the deferred "CSS pipeline" conversation flagged in the InboxLive moduledoc (WR-03) — that needs its own scope.

---

## Plan-breakdown shape

| Option | Description | Selected |
|--------|-------------|----------|
| Single megaplan | One PLAN.md covers telemetry + facade + polish in one wave. | |
| Three sequential waves (mirrors Phase 25) | Wave 1 telemetry substrate → Wave 2 facade → Wave 3 polish. | ✓ |
| Two waves (substrate + polish) | Telemetry + facade in Wave 1; polish in Wave 2. | |

**Auto-decided choice:** Option 2 (three waves).
**Rationale:** Phase 25 established the wave-per-concern posture and it kept each plan reviewable. The substrate (telemetry) wants its own wave so the OI module can be inspected against the Phase 17 pattern before any consumer (facade or UI) lands on top.

---

## Claude's Discretion

The following are explicitly left to the planner / researcher's judgment within the constraints recorded in `26-CONTEXT.md`:

- **OI trace event atom granularity** — within the `@events` enum guard (D-03), planner may add or remove one atom if a finer/coarser split emerges. Outcome must remain enum-only per D-01.
- **Inbox empty-state exact wording** — within D-08, planner picks exact copy provided it's calm, reason-forward, no emoji, no exclamation marks.
- **Test naming + file layout for the new traces module** — within D-12, planner picks consistent naming with `test/cairnloop/governance/telemetry_test.exs`.

---

## Deferred Ideas

Captured in `26-CONTEXT.md` `<deferred>` block for cross-reference:

- Operator-visible `BulkOutboundHistoryLive` — flagged for cheap veto on D-07.
- Per-conversation outbound trigger audit READ facade — future phase if host demand surfaces.
- Consolidated `Cairnloop.Outbound.Telemetry` umbrella module — mirrors Phase 17 posture (sibling modules, no merge).
- Extracting duplicated brand-token button styles to a CSS class — needs a CSS-pipeline phase.
- Centralising duplicated fail-closed search guards (pending todo from `STATE.md`) — not outbound-domain.
- Root `SECURITY.md` open threats T-10-09..T-10-13 (vM010 carry) — not outbound-domain; pre-existing debt.
- `Oban.Telemetry` integration — Oban already emits its own; Phase 26 adds Cairnloop-domain semantics on top, not duplication.

---

## Shift-left posture notes

Per `CLAUDE.md` "Decision policy (shift-left — IMPORTANT)":

- No `AskUserQuestion` calls were made during this discuss-phase invocation. The advisor-mode default would have spawned four parallel research agents and presented comparison tables — that pattern is explicitly overridden by the project CLAUDE.md ("surface at most the single genuinely VERY-impactful call").
- Two decisions are flagged for cheap owner veto (D-03 OI module; D-07 no first-party operator UI). Both are reversible without rework — D-03 by dropping the traces module from Wave 1; D-07 by adding a plan to Wave 3 — so neither qualified as VERY-impactful by the CLAUDE.md criterion ("expensive/irreversible to undo, materially change product scope or the trust/governance model").
- All decisions were grounded in either (a) explicit requirement text (OBS-01, OBS-02), (b) carried decisions from STATE.md / Phase 25 CONTEXT, or (c) the Phase 17 pattern that established the OI conformance precedent.

---

*Audit trail end.*
