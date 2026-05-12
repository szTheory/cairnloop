# Research Summary: Customer Voice Activation (Customer-Led Growth)

**Domain:** Customer Support in B2B SaaS (Customer-Led Growth)
**Researched:** 2024-05
**Overall confidence:** HIGH

## Executive Summary

In 2024, the B2B SaaS ecosystem has shifted from "growth at any cost" (PLG-only) to efficient, retention-focused "Customer-Led Growth" (CLG). Support centers are uniquely positioned for CLG because resolving a critical issue or bug is the highest leverage point for creating a brand advocate. By intercepting angry users, companies prevent negative public reviews, while instantly solving issues for satisfied users creates an optimal moment to ask for an App Store or G2 review.

Cairnloop's approach to this domain avoids building a heavyweight, generic marketing CRM. Instead, it relies on a highly decoupled architecture utilizing Elixir's native `:telemetry` library. By emitting high-signal events upon conversation resolution, Cairnloop provides the "spark" and context (e.g., duration, sentiment shift). The host application can then attach standard telemetry handlers to trigger external growth actions (like a native iOS App Store review prompt, or a Slack alert to a Customer Success Manager).

## Key Findings

**Stack:** Idiomatic Elixir utilizing `:telemetry` for event dispatch, ensuring Cairnloop remains decoupled from the host's growth infrastructure.
**Architecture:** Event-driven pipeline where `[:cairnloop, :conversation, :resolved]` acts as the critical lifecycle hook.
**Critical pitfall:** Survey fatigue and generic email CSATs. Feedback must be in-app, contextual, and frictionless to maintain high response rates and avoid annoying users.

## Implications for Roadmap

Based on research, suggested phase structure for M004:

1. **Phase 1: Foundation (Telemetry & Events)** - Establish the `[:cairnloop, :conversation, :resolved]` pipeline.
   - Addresses: The core decoupling requirement; allows host apps to immediately start acting on resolutions.
   - Avoids: Hardcoding third-party review platforms into Cairnloop.

2. **Phase 2: Sentiment Capture (CSAT/CES UI)** - Introduce frictionless in-widget CSAT and Customer Effort Score (CES) capture.
   - Addresses: The need for low-cognitive-load, one-click feedback immediately after a ticket closes.
   - Avoids: Generic email surveys which suffer from low open rates.

3. **Phase 3: Host Extensibility & Reference Implementations** - Build reference handlers and documentation for the host.
   - Addresses: Developer Experience (DX). The host must understand exactly how to wire up the telemetry signal to a G2/App Store prompt.

**Phase ordering rationale:**
- The telemetry pipeline must exist before we can attach sentiment to it. Once the pipeline is built, capturing CSAT provides the data payload for the events. Finally, reference implementations prove the architecture works in real-world host apps.

**Research flags for phases:**
- Phase 2: Needs deep research into UI/UX best practices for capturing CES (Customer Effort Score) vs CSAT, as CES is often a better predictor of churn in SaaS.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | `:telemetry` is the definitive standard for Elixir observability and event decoupling. |
| Features | HIGH | CLG and in-app sentiment capture are well-established SaaS patterns. |
| Architecture | HIGH | Event-driven architecture fits perfectly with Phoenix/Elixir paradigms. |
| Pitfalls | HIGH | Survey fatigue is a documented, pervasive issue in customer success. |

## Gaps to Address

- UI specifications for the CSAT/CES micro-interactions inside the existing `WidgetLive`.
- How to handle "Detractor" routing directly to host systems without blocking the main telemetry thread.
