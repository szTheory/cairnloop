# Validation Plan: Foundation (Telemetry & Events)

This document outlines the testing strategy for the phase.

## Test Coverage
- `test/cairnloop/chat_test.exs` MUST verify the `[:cairnloop, :conversation, :resolved]` telemetry event is emitted correctly when a conversation is resolved.
- Payload MUST contain `conversation_id` and `duration_seconds`.

## Manual Verification
- Review documentation to ensure it clearly explains how to hook into the `[:cairnloop, :conversation, :resolved]` event.
- Ensure reference handler examples are included in the documentation.
