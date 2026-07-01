# Security Policy

## Supported Versions

Cairnloop is pre-1.0 OSS. Security fixes target the latest released version and `main` unless a
maintainer explicitly states otherwise in a release note.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories when available,
or by opening a minimal private contact request with the maintainer. Do not include working exploit
details in a public issue.

Include:

- affected version or commit
- impact and attacker capability
- reproduction steps
- relevant configuration, especially Phoenix/Ecto/Oban setup
- route/auth exposure, especially public dashboards, webhooks, MCP endpoints, or bypassed host auth
- whether sensitive customer/support data can be exposed, modified, or deleted

## Scope

Security-sensitive Cairnloop areas include:

- operator identity and host-auth integration
- email/webhook ingress
- governed tool approvals and outbound side effects
- MCP tokens and admin surfaces
- knowledge-base suggestion and editor handoff flows
- telemetry/logging of customer-support content
- database migrations, schema-prefix behavior, and rollback safety

Cairnloop is embedded in a host Phoenix app. Host applications remain responsible for route
authentication, authorization policy, secret storage, TLS, network controls, backup/restore, and
production monitoring.

## Response Posture

The maintainer will triage credible reports, keep the reporter updated when practical, and prefer a
small, test-backed fix plus a clear release note. For severe issues, public details should wait until
a patched release is available.
