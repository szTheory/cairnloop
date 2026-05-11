# Phase M003-S01 Validation

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/cairnloop/context_provider_test.exs test/cairnloop/web/conversation_live_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| S01-1 | Default provider returns empty ok tuple | unit | `mix test test/cairnloop/context_provider_test.exs` | ✅ Yes |
| S01-2 | LiveView resolves provider via app config | unit/integration | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ Yes |
| S01-3 | LiveView handles error tuple gracefully | unit/integration | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ Yes |

### Sampling Rate
- **Per task commit:** `mix test <path-to-test-file>`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`
