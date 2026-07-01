# Phase 58: Identity, Ingress, and Side-Effect Trust - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 58-Identity, Ingress, and Side-Effect Trust
**Areas discussed:** identity boundaries, ingress auth, sensitive logs/telemetry, optional side
effects, doctor/readiness

---

## Identity Boundaries

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve widget token as `host_user_id` | Minimal churn but keeps customer/session identity conflated with operator/governance identity. | |
| Add explicit customer/session identity seam | Separates browser/customer identity from operator identity and matches TRUST-01/TRUST-02. | yes |
| Defer identity persistence until Phase 59 | Avoids a migration now but leaves the Phase 58 requirement unsatisfied. | |

**User's choice:** Auto-decided per repo policy.
**Notes:** `CLAUDE.md` says GSD discuss-phase should auto-decide routine trust-sensitive calls and
surface at most one genuinely very impactful decision. This is required by Phase 58 scope and can be
done additively.

---

## Ingress Auth

| Option | Description | Selected |
|--------|-------------|----------|
| Demo-friendly defaults | Keeps existing flows easy but leaves production ingress too permissive. | |
| Fail-closed host verifier/token seams | Requires explicit host config before accepting widget/email/MCP ingress. | yes |
| Build provider-specific auth/product flows | More complete for some providers but expands scope beyond trust hardening. | |

**User's choice:** Auto-decided per repo policy.
**Notes:** Email remains a narrow authenticated stub. MCP should protect `tools/list` and
`tools/call`, and should require auth for `initialize` unless spec research demands a minimal public
handshake with no tool metadata.

---

## Sensitive Logs/Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Keep current conversation metadata | Least churn but risks raw support content or unbounded host metadata leakage. | |
| Normalize conversation telemetry like retrieval/governance/outbound | Uses established bounded-metadata patterns and preserves durable DB/audit truth. | yes |
| Add broad diagnostic logging | Useful during debugging but unsafe as a default support-software posture. | |

**User's choice:** Auto-decided per repo policy.
**Notes:** Diagnostic detail may exist only behind explicit opt-in. Default logs/telemetry should not
include bodies, raw payloads, secrets, or arbitrary metadata.

---

## Optional Side Effects

| Option | Description | Selected |
|--------|-------------|----------|
| Always attach/enqueue Scrypath bridge | Violates OPS-01 and can surprise hosts. | |
| Keep Scrypath opt-in with doctor/strict validation | Matches vM019 decisions and live source direction. | yes |
| Remove Scrypath integration entirely | Safer but unnecessary churn to an existing optional seam. | |

**User's choice:** Auto-decided per repo policy.
**Notes:** Source already gates the telemetry handler behind `:scrypath_automation_enabled`; planning
should add enabled-state validation, dummy credential rejection, docs, and tests.

---

## Doctor/Readiness

| Option | Description | Selected |
|--------|-------------|----------|
| Make `/health` deep readiness | Tempting but turns liveness into an expensive and potentially misleading endpoint. | |
| Keep `/health` shallow; extend doctor/readiness truth | Matches current architecture and OPS-03/OPS-04. | yes |
| Add no operational checks | Leaves adoption/support trust gap open. | |

**User's choice:** Auto-decided per repo policy.
**Notes:** `mix cairnloop.doctor` is the primary deep diagnostic surface. A runtime readiness endpoint
is optional only if honest and opt-in under operations routing.

---

## Claude's Discretion

- No owner question was escalated. The roadmap, requirements, Phase 57 audit, and repo decision policy
  already lock the fail-closed direction.
- Exact module/function names for new verifier seams are left to researcher/planner after codebase
  analysis, as long as the decisions in CONTEXT.md hold.

## Deferred Ideas

- Full provider-specific email product workflow.
- Phase 59 schema-prefix implementation.
- Phase 60 broad docs/package/security/upgrading truth.
- Phase 61 CI/CD workflow changes.
