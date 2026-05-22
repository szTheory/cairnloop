# Context: M005-S03 Alerting & Runbooks

## Overview
This phase delivers the final piece of the M005 milestone: integrating Cairnloop with Parapet to provide SRE-grade observability and runbook scaffolding out-of-the-box.

## Key Decisions (Resolved via Discuss Phase)

### 1. Artifact Distribution
We will exclusively use **Igniter Generation** to place SLO definitions (`lib/my_app/cairnloop/slos.ex`), Doctor checks (`MyApp.Cairnloop.Doctor`), and Runbooks physically into the host application. We reject the "hidden library macro" approach (e.g. `use Cairnloop.SLOs`) because operators must have perfect visibility and the ability to customize escalation paths.

### 2. Runbook Location
Igniter will generate Markdown runbooks (e.g., `cairnloop_queue_backup.md`) directly into `priv/runbooks/`. This convention keeps runbooks packaged with OTP releases while cleanly separating them from `lib/` source code.

### 3. Default SLO Scaffolding
Rather than a minimalist (TTFR-only) or naive (TTFR + Resolution Time only) approach, we will scaffold a complete trinity of metrics that connect business outcomes to backend realities:
1. **Time to First Response (TTFR)**
2. **Resolution Time**
3. **Cairnloop-scoped System Health** (e.g., AI drafting latency or stale handoffs).

*Rationale:* This prevents "alert fatigue" common in tools like Zendesk, and prevents metric duplication with Parapet's universal Oban metrics. It honors Parapet's SRE vision: catching automation stalls before they become customer-facing TTFR breaches.