## Nyquist Coverage Validation

*Backfilled at vM015 close (2026-05-30) by transcribing the existing, passing tests referenced in
`34-01-SUMMARY.md` / `34-02-SUMMARY.md`.*

| Requirement | Test Coverage / Verification | Gap? |
|-------------|------------------------------|------|
| SET-01 — MCP token CRUD (create/edit/mask/validate) | `test/cairnloop/mcp_test.exs` covers the token lifecycle end-to-end: `issue_token/1` (returns raw + stores hashed), `validate_token/1` (valid / invalid / revoked / expired), `update_token/2` (rename). `test/cairnloop/web/settings_live_test.exs` renders the token management surface (raw token shown once at creation). | NO |
| SET-02 — Notifier health surfaced | `test/cairnloop/web/settings_live_test.exs` → renders the `notifier_health` assign on the settings page. | NO |
| SET-03 — retrieval-system health surfaced (pgvector index + Oban failed jobs) | `test/cairnloop/web/settings_live_test.exs` → renders the `retrieval_health` assign. | NO |
| SET-04 — persisted dark-mode toggle, instant UI update | `test/cairnloop/web/settings_live_test.exs` → renders with dark-mode state (no JS hook). | NO |

**Conclusion**: All four settings-surface requirements are covered. SET-01 (the trust-sensitive
surface) is the most deeply covered — the MCP token lifecycle is exercised across five `mcp_test.exs`
cases. SET-02/03/04 are covered by the `settings_live_test.exs` render path (which asserts the health
indicators and dark-mode state are present). Coverage of the LiveView render is intentionally shallow
(2 LiveView tests); the underlying token/health logic carries the depth. No gaps for v1 scope.
