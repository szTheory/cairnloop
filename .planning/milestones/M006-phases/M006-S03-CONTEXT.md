# M006-S03: LiveView SLA Configuration Context

## Objective
Operators need a frictionless, embedded UI to configure SLA thresholds (e.g., Time to First Response, Time to Resolution) directly within the Cairnloop dashboard. 

## Architectural Decisions
As part of the GSD Discuss Phase, the following architecture has been deeply researched and established for this feature:

1. **Storage (Host-Owned, Versioned Policy Pattern)**
   Instead of burying SLA configuration in a mutable internal library table, Cairnloop will use an Igniter recipe (`mix cairnloop.install`) to scaffold an immutable, versioned Ecto schema directly into the Host application. Cairnloop will interact with this schema via a defined Behaviour (`Cairnloop.SLAPolicyProvider`). This guarantees temporal correctness for SRE audits (Threadline/Parapet) while maintaining a batteries-included DX.

2. **UI Location (Dedicated `/settings` Route)**
   The settings dashboard will NOT be a modal within the `InboxLive` queue. It will be a dedicated LiveView route (e.g., `/settings`) injected via the `cairnloop_dashboard/2` macro. This prevents the primary operator queue process from bloating with administrative form states and creates a dedicated foundation for future RBAC and team settings.

3. **Priority Modeling (Static `Ecto.Enum`)**
   The system will rely on a static enum (`[:low, :normal, :high, :urgent]`) for priorities rather than allowing operators to dynamically create custom tiers. This removes complex joining logic from the Oban SLA breach workers and provides maximum type safety. If a host needs custom priorities, they can modify their Igniter-generated Ecto schema.

4. **SLA Metric Structure (Explicit Columns)**
   SLA durations will be modeled as explicit integer columns (e.g., `target_first_response_minutes`) on the policy table rather than unstructured JSONB payloads. This ensures Oban sweep queries are fully indexed and performant across millions of records.
