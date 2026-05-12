# M005 Research: Durable Auditing & SRE Observability

## Executive Summary
This document synthesizes deep architectural research for Cairnloop’s Phase 1, 2, and 3 deliverables for the M005 milestone (Durable Auditing & SRE Observability). Cairnloop integrates with its sibling libraries, Threadline (durable evidence/audit) and Parapet (SRE observability), to provide a robust, operator-friendly customer support automation engine.

The core tension in library design is between **ergonomics (magic)** and **ownership (explicitness)**. Aligning strictly with the engineering DNA of Parapet and Threadline, the overarching philosophy for Cairnloop is: **Host-owned wiring, strict cardinality safety, and atomic evidence over lossy telemetry.**

---

## Decision 1: Phase 1 (Durable Auditing)
**Question:** Threadline requires durable evidence. Should Cairnloop define an explicit `Cairnloop.Auditor` behavior called inside Ecto transactions (e.g., `audit_multi/4`), or should we just emit Telemetry events that a host app's Threadline config listens to?

### Pros/Cons & Tradeoffs
*   **Telemetry Events:**
    *   *Pros:* Extremely decoupled. Cairnloop just emits `[:cairnloop, :ticket, :resolved]`; the host app decides if/how to record it. Feels very "library-like".
    *   *Cons:* **Breaks transaction boundaries and sacrifices atomicity.** Telemetry handlers run either synchronously (but outside the safety of the specific Ecto Multi) or asynchronously. If the main transaction commits but the DB connection for the audit log fails in the telemetry handler, the audit log is lost. If the handler raises an error inside the transaction's connection scope, it might roll back the main transaction opaquely. This violates Threadline's core requirement for *durable* evidence.
*   **Explicit `Cairnloop.Auditor` Behavior in Ecto `Multi`:**
    *   *Pros:* **Guaranteed Atomicity.** The audit record is inserted in the exact same database transaction as the state change. If the action succeeds, the audit trail is guaranteed to exist. If the audit fails, the action rolls back.
    *   *Cons:* Slightly higher coupling. Requires the host app to configure a module that implements this behavior.

### Idiomatic Elixir & Lessons Learned
For transient, lossy metrics (like latency or queue depth), Telemetry is king. However, for **durable, atomic state changes** (like the outbox pattern, audit logs, or webhooks), relying on Telemetry is a known anti-pattern in Elixir. Libraries like Oban explicitly rely on `Ecto.Multi` integration (`Oban.insert/2` takes a Multi) to ensure job atomicity. Similarly, generic auth libraries (like Pow) provide extension callbacks that inject operations directly into the Ecto Multi pipeline rather than relying on PubSub/Telemetry for critical state.

### One-Shot Cohesive Recommendation
**Adopt the `Cairnloop.Auditor` behavior injected via `Ecto.Multi`.**
Cairnloop should define a `Cairnloop.Auditor` behavior with a callback like `audit(multi, action, resource, metadata)`. By default, Cairnloop ships with a `Cairnloop.Auditor.Noop` that simply passes the `Multi` through unchanged. The host app configures `config :cairnloop, auditor: MyApp.ThreadlineAuditor`. When Cairnloop processes a ticket, it passes its `Multi` to the auditor, allowing the host app's Threadline integration to append an `Ecto.Multi.insert` for the audit log. This guarantees absolute transactional integrity and durable evidence, perfectly aligning with Threadline's mandate.

---

## Decision 2: Phase 2 (Metrics Emission)
**Question:** How should Cairnloop expose its SLIs (e.g., Time to First Response, Resolution Time) safely for Parapet without exploding cardinality?

### Pros/Cons & Tradeoffs
*   **Raw Telemetry Emission (Host filters everything):**
    *   *Pros:* Zero Parapet coupling in Cairnloop.
    *   *Cons:* Shifts the entire burden of metric curation to the host app. High risk of cardinality explosion if a junior dev mistakenly uses `:ticket_id` as a Prometheus label.
*   **Built-in `Cairnloop.Parapet.Instrumenter`:**
    *   *Pros:* Perfect plug-and-play DX.
    *   *Cons:* Violates the "Host-Owned" principle. Hides metric definitions in a black-box library, making it hard for adopters to tweak label mappings.
*   **Strictly Contracted Telemetry + Igniter Generation:**
    *   *Pros:* Combines safe defaults with full host ownership. Cairnloop emits rich Telemetry, but formally documents low vs. high cardinality fields.

### Idiomatic Elixir & Lessons Learned
The Elixir `telemetry` library convention is to provide a flat map of metadata. However, SRE tools (Prometheus, Parapet) strictly differentiate between **labels** (low cardinality: `:queue`, `:status`, `:escalation_level`) and **evidence** (high cardinality: `:ticket_id`, `:user_id`). Libraries like `ecto_sql` or `plug` just emit everything and let standard instrumenters (like `telemetry_metrics`) handle the mapping. But for high-level business SLIs, the risk of cardinality explosion is severe.

### One-Shot Cohesive Recommendation
**Emit strictly partitioned Telemetry metadata and generate a Parapet Instrumenter into the host app via Igniter.**
Cairnloop should emit standard Telemetry events (e.g., `[:cairnloop, :ticket, :resolved]`), but its metadata payload must explicitly partition dimensions:
```elixir
%{
  labels: %{queue: "billing", priority: "high", status: "resolved"},
  evidence: %{ticket_id: 123, agent_id: 456}
}
```
Cairnloop will provide an Igniter task (`mix cairnloop.gen.parapet`) that injects a physical `MyApp.Cairnloop.Instrumenter` module into the host app. This generated code explicitly maps `metadata.labels` to Parapet/Prometheus labels and pushes `metadata.evidence` to structured logs or OpenTelemetry spans. This prevents cardinality explosions by default while allowing operators to physically see, own, and modify the metrics mapping.

---

## Decision 3: Phase 3 (Runbooks and SLOs)
**Question:** How should Cairnloop distribute its `mix parapet.doctor` checks, runbooks, and SLO definitions to the host app? Igniter generation into the host app vs. runtime configuration (macros)?

### Pros/Cons & Tradeoffs
*   **Runtime Configuration / Macros (e.g., `use Cairnloop.SLOs`):**
    *   *Pros:* Always up-to-date. If Cairnloop v2.0 introduces a new SLO, the host app gets it for free upon upgrade.
    *   *Cons:* Violates Parapet's "Host-Owned Over Magical Black-Boxes" tenet. SLO targets (e.g., "Time to First Response < 4 hours") are deeply business-specific. Hiding them behind library macros makes overriding painful and obfuscates the reliability definitions from operators who need to read them.
*   **Igniter Generation into Host App:**
    *   *Pros:* Perfect visibility. Operators can read the `MyApp.Cairnloop.SLO` file and tweak the target from 4 hours to 2 hours. The runbooks live in the host repo's `priv/runbooks/` and can be edited to include company-specific escalation paths (e.g., "Page @oncall in #support-eng").
    *   *Cons:* Updates to Cairnloop's recommended SLOs require Igniter patchers or manual host intervention upon library upgrades.

### Idiomatic Elixir & Lessons Learned
The Ruby-on-Rails (Devise) and Elixir (Pow, Phoenix Auth) ecosystems have consistently proven that **generation is superior to metaprogramming for business-specific configuration.** While core protocol logic should be immutable and hidden in the library, things like UI views, authentication flows, and **Service Level Objectives** are business-owned. A library can only provide a *template* or a *suggestion* for an SLO; the business must ultimately own the target and the runbook.

### One-Shot Cohesive Recommendation
**Distribute via Igniter Generation for total host ownership.**
Cairnloop should use `Igniter` to physically generate the reliability artifacts into the host repository:
1.  **SLOs:** Generate `lib/my_app/cairnloop/slos.ex` containing explicit `Parapet.SLO.define/2` calls for TTFR and Resolution Time.
2.  **Runbooks:** Generate Markdown files into `priv/runbooks/cairnloop_queue_backup.md` that include Cairnloop's baseline debugging steps, leaving space for the host to add their PagerDuty policies.
3.  **Doctor Checks:** Generate a `MyApp.Cairnloop.Doctor` module implementing `Parapet.Doctor` behavior (e.g., checking if the Cairnloop Oban queues are running and Ecto constraints are valid) and register it in the host's `mix.exs`.

This guarantees that Parapet operators have complete visibility, standard operator UX, and the ability to tailor their reliability posture without fighting library abstractions.