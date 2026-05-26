# Validation Plan: The Notifier Behaviour & Chimeway

This document outlines the testing strategy for Phase 2.

## Test Coverage
- `test/cairnloop/notifier_test.exs` MUST verify the `Cairnloop.Notifier` behaviour callbacks.
- `test/cairnloop/notifier/chimeway_test.exs` MUST verify `Cairnloop.Notifier.Chimeway` triggers Chimeway successfully with an idempotency key.
- `test/cairnloop/workers/check_sla_test.exs` MUST verify the worker dynamically calls `on_sla_breach` on the configured notifier.

## Manual Verification
- Review codebase to ensure `mix deps.get` completes successfully with `chimeway` installed optionally.
