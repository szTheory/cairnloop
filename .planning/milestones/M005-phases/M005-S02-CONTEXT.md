# M005-S02: SRE Observability (SLIs) Context

## Phase Goal
Support operation metrics are cleanly surfaced as quantitative indicators for reliability tracking via Parapet.

## Key Decisions (Discuss Phase)

**Architecture: Scaffold via Igniter (Host-Owned Instrumenter)**
- **Decision:** We will provide an Igniter task (`mix cairnloop.install.parapet`) to scaffold a `HostApp.CairnloopInstrumenter` into the host application.
- **Rationale:** Aligns with Parapet's "Host-Owned Over Magical Black-Boxes" core tenet. Adopters get a visible, auditable, and easily customizable mapping of telemetry to metrics without hidden DSLs or black-box modules.
- **Reference:** Confirmed in `.gsd/DECISIONS.md`.

**Default SLI Mappings (Out-of-the-box)**
The generated instrumenter will automatically hook into existing Cairnloop telemetry events to emit the following Parapet metrics:
1. `[:cairnloop, :conversation, :resolve, :stop]` ➡️ `support_resolution_time`
2. `[:cairnloop, :conversation, :reply, :stop]` ➡️ `support_reply_time`
3. `[:cairnloop, :feedback, :csat, :stop]` ➡️ `support_csat_score`

## Next Steps
The decision tree is resolved. This slice is fully aligned and ready for the plan/execution phases.