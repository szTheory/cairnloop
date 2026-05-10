---
phase: M001
plan: 01
subsystem: Ingress
tags: [oban, channels, email, ingress, mailglass]
requires: []
provides: [cairnloop/workers/process_message, cairnloop/channels/widget_socket, cairnloop/channels/widget_channel, cairnloop/ingress/email_parser, cairnloop/ingress/email_webhook_plug]
affects: [mix.exs]
tech-stack:
  added: [oban, mailglass, hackney]
  patterns: [oban worker, phoenix channel, plug]
key-files:
  created: [
    "lib/cairnloop/workers/process_message.ex",
    "lib/cairnloop/channels/widget_socket.ex",
    "lib/cairnloop/channels/widget_channel.ex",
    "lib/cairnloop/ingress/email_parser.ex",
    "lib/cairnloop/ingress/email_webhook_plug.ex"
  ]
  modified: ["mix.exs"]
key-decisions:
  - "Used a simple regex for email parsing since Mailglass did not have a built-in inbound parse method as mistakenly assumed in the plan."
metrics:
  duration: 15m
  completed_at: 2024-11-20T12:00:00Z
---

# Phase M001 Plan 01: Multi-Channel Ingress Engine Summary

Implemented Oban pipeline and multi-channel ingress handlers for Cairnloop to support real-time web widgets and async email ingestion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced Mailglass.parse with regex fallback**
- **Found during:** Task 3
- **Issue:** The plan hallucinated that `Mailglass.parse/1` exists to parse inbound emails, but Mailglass is exclusively an outbound transactional framework.
- **Fix:** Substituted `Mailglass.parse` with a regex-based string split operation to separate quoted replies from new content.
- **Files modified:** `lib/cairnloop/ingress/email_parser.ex`
- **Commit:** 1fbef35

**2. [Rule 3 - Blocker] Missing Hackney dependency for Swoosh**
- **Found during:** Task 3
- **Issue:** The `mailglass` library brings in `swoosh` as a dependency, which expects a HTTP client. Compiling/running failed due to missing `:hackney` module.
- **Fix:** Added `{:hackney, "~> 1.9"}` to `mix.exs`.
- **Files modified:** `mix.exs`
- **Commit:** 1fbef35

## Known Stubs

- **Stub:** `ProcessMessage.perform/1` just logs instead of doing DB inserts.
  - **File:** `lib/cairnloop/workers/process_message.ex:8`
  - **Reason:** Core database context for persisting messages does not exist yet.
- **Stub:** `WidgetSocket.connect/3` fakes user authentication check.
  - **File:** `lib/cairnloop/channels/widget_socket.ex:12`
  - **Reason:** Auth provider / token checking is missing.
- **Stub:** `WidgetChannel.join/3` assumes token presence means access to private rooms.
  - **File:** `lib/cairnloop/channels/widget_channel.ex:10`
  - **Reason:** Roles and access controls not defined yet.
- **Stub:** `EmailWebhookPlug.verify_signature/1` hardcodes `"secret-token"` check.
  - **File:** `lib/cairnloop/ingress/email_webhook_plug.ex:34`
  - **Reason:** Real provider signature verification (e.g., Postmark) will require app secrets configuration.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: missing_auth | `lib/cairnloop/channels/widget_socket.ex` | WebSocket connections allow users to fake auth tokens (mitigation added to plan but only stubbed in code). |
| threat_flag: hardcoded_secret | `lib/cairnloop/ingress/email_webhook_plug.ex` | Webhook verification accepts a mock static secret token header. |

## Self-Check: PASSED
