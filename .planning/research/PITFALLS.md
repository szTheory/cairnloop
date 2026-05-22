# Domain Pitfalls

**Domain:** Support Ticketing SLA Management & Notification Routing
**Researched:** Current Date

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Oban Table Bloat & Queue Clutter
**What goes wrong:** Millions of `CheckSLA` jobs sit in the `oban_jobs` table, bloating the database and slowing down the polling mechanism.
**Why it happens:** Every ticket creation inserts an SLA job. If the system experiences extreme volume, the sheer number of pending jobs degrades DB performance.
**Consequences:** Delayed SLA execution, database CPU spikes, and autovacuuming struggles.
**Prevention:** 
1. Use Oban Pruner to aggressively delete `completed` or `discarded` jobs.
2. At hyper-scale, consider partitioned schemas for jobs as noted in Oban's advanced scaling docs.
**Detection:** `oban_jobs` table size grows exponentially; `CheckSLA` jobs execute later than their scheduled time.

### Pitfall 2: Orphaned Escalations (False Positives)
**What goes wrong:** A ticket is resolved by an agent, but 2 hours later, the Slack channel receives an "SLA Breached!" alert for that ticket.
**Why it happens:** The Oban job fired, but failed to check if the ticket was still in a state that required an escalation.
**Consequences:** Agents lose trust in the alerting system ("Cry Wolf" syndrome) and start ignoring the Slack channel.
**Prevention:** Make the `CheckSLA` worker strictly re-evaluate the `Conversation` status at the moment of execution. If it's resolved, return `:ok` and do nothing.

## Moderate Pitfalls

### Pitfall 1: API Rate Limiting from Delivery Channels
**What goes wrong:** A massive surge of SLA breaches triggers simultaneously, spamming the Slack API and resulting in HTTP 429 Too Many Requests.
**Prevention:** Push the actual outbound delivery to a dedicated Oban queue (e.g., `notifications`) with a strict concurrency limit (e.g., `global_limit: 5`). Rely on Chimeway's adapter to handle retries cleanly.

## Minor Pitfalls

### Pitfall 1: Weekend / Holiday Hours
**What goes wrong:** A 4-hour SLA triggers on a Saturday morning because the countdown used strict wall-clock time.
**Prevention:** For the MVP, clearly communicate that SLAs are wall-clock based. In future iterations, pass a `business_hours: true` flag to the scheduling logic to compute the correct `scheduled_at` datetime.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Job Scheduling (Oban) | Race conditions checking state | Rely on Ecto's atomic state (status = unresolved) inside the worker logic rather than trying to delete pending jobs. |
| LiveView Config | Malformed SLA times | Force SLA values to be strictly defined integers (e.g., minutes) in the UI, translated to `schedule_in` tuples for Oban. |

## Sources

- Oban Scaling & Reliability Guides.
- Industry standard Alert Fatigue post-mortems.