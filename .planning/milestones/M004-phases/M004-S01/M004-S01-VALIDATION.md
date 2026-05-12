# Phase M004-S01 Validation

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/cairnloop/chat_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TLM-01/02 | `resolve_conversation` updates `resolved_at` and requires `resolved_by` actor | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Yes |
| TLM-01/02 | `resolve_conversation` emits telemetry with duration | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Yes |
| TLM-01/02 | `reply_to_conversation` resets `resolved_at` to nil | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Yes |
| EXT-01 | Extensibility separation documented (`:telemetry` vs `Notifier`) | manual | N/A | ✅ Yes |

### Sampling Rate
- **Per task commit:** `mix test <path-to-test-file>`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`