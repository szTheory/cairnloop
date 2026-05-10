# Cairnloop: Project Context & Engineering DNA

## 1. Product Vision: SupportOS
Cairnloop is a Phoenix-native, embedded customer support automation layer. It is **not** a generic, standalone Helpdesk clone. It is designed for solo SaaS operators and small engineering teams running Phoenix apps.
- **Core Loop**: Turn support conversations into answers, product signals, knowledge-base improvements, and safe automated actions.
- **Embedded Nature**: Host-owned routing, Ecto-native state, and app-context aware (billing, auth, etc.).
- **V1 Features**: In-app widget, email ingress/egress adapters, comprehensive KB, AI drafting, and triage/classification.

## 2. "SaaS in a Box" DNA & Philosophy
Following the success of sibling libraries (Threadline, Scoria, Parapet), Cairnloop must adhere to these principles:
- **Host-Owned**: No magical black boxes. Use `Igniter` to generate boilerplate and migrations into the host application.
- **Ecto-Native**: Messages are append-only. Use Ecto changesets and `Ecto.Multi` for explicit state transitions and durable storage.
- **Operator-First DX**: Visual onboarding, embedded LiveView dashboards, and day-2 operations (`mix cairnloop.doctor`) out of the box.
- **Behaviours over DSLs**: Avoid massive macro DSLs. Rely on explicit behaviours (e.g., `ChannelAdapter`, `AutomationPolicy`, `Notifier`).

## 3. Telemetry & Observability
- **Strict Public API**: Telemetry events (`[:cairnloop, :conversation, :opened]`) are deliberate. Breaking them is a semver-major change.
- **OpenInference Standards**: AI traces and spans must align with OpenInference conventions.
- **Cardinality Safety**: High-cardinality data belongs in structured metadata or durable evidence stores, not in Prometheus metric labels.

## 4. Ecosystem Integrations (Cross-Library Synergy)
- **Parapet (SRE)**: Consume Cairnloop's SLIs for SLO alerting and operator diagnostics.
- **Scoria (AI Governance)**: Handle AI traces, evaluations, and tool approvals (Human-in-the-loop).
- **Sigra (Auth)**: Protect the embedded LiveView dashboard and provide user identity context.
- **Threadline (Audit)**: Provide durable context for human approvals and critical AI state changes.
- **Chimeway & Mailglass**: Handle asynchronous operator notifications and inbound/outbound email support parsing.
- **Accrue & Rindle**: Provide billing and media context to support conversations.

## 5. CI/CD & Reliability Best Practices
- **Defensive & Contract-Driven**: Ensure the library's "shape" is tested via Doc contract tests and release shape verification.
- **Multi-Stage Validation**: Utilize `verify.*` aliases (`verify.format`, `verify.credo`, `verify.test`).
- **Core Stability**: Test core compilation strictly without optional dependencies to ensure correct modular boundaries.
