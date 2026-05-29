# Phase 36: Documentation & v0.2.0 Release - Pattern Map

**Mapped:** 2024-05-29
**Files analyzed:** 5
**Analogs found:** 4 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/05-mcp-clients.md` | documentation | None | `guides/01-quickstart.md` | exact |
| `guides/06-extending.md` | documentation | None | `guides/03-host-integration.md` | exact |
| `docs/architecture.md` | documentation | None | `docs/cairnloop-jtbd-and-user-flows.md` | exact |
| `CHANGELOG.md` | documentation | None | `CHANGELOG.md` | exact |
| `CONTRIBUTING.md` | documentation | None | None | none |

## Pattern Assignments

### `guides/05-mcp-clients.md` (documentation, None)

**Analog:** `guides/01-quickstart.md`

**ExDoc Guide Header pattern** (lines 1-7):
```markdown
# Quickstart

Get from a fresh clone to a running Cairnloop operator dashboard in a few minutes.
This guide follows the example app at `examples/cairnloop_example/` as its reference.

## Prerequisites
```

---

### `guides/06-extending.md` (documentation, None)

**Analog:** `guides/03-host-integration.md`

**Behaviour/Integration Guide pattern** (lines 1-10):
```markdown
# Host Integration

Cairnloop exposes four behaviour contracts that let your host application control the
support lifecycle without giving up ownership of your data or business logic. Each behaviour
is a plain Elixir `@behaviour` module — implement the callbacks, configure the module, and
Cairnloop uses your implementation at the right moment.

This guide documents all four behaviours and their full callback sets, in the order a new
adopter would typically implement them. It also covers Cairnloop's telemetry emission points
as an observability reference.
```

---

### `docs/architecture.md` (documentation, None)

**Analog:** `docs/cairnloop-jtbd-and-user-flows.md`

**Architectural Document pattern** (lines 1-13):
```markdown
# Cairnloop, From a Phoenix SaaS Builder's Perspective

Cairnloop is not "Zendesk, but in Elixir."

It is closer to an embedded support operations layer for Phoenix apps: a support inbox, a conversation workspace, a knowledge base, a retrieval system, a safe AI draft loop, SLA tracking, and host-controlled extension points for app-specific actions.

The most useful way to think about it is this:

> Cairnloop helps you keep support inside your monolith, close to your product data, and close to the operators who need to make judgment calls.

That is the good news.
```

---

### `CHANGELOG.md` (documentation, None)

**Analog:** `CHANGELOG.md`

**Keep-a-changelog format pattern** (lines 8-15):
```markdown
## [Unreleased]

### Added

- Realistic demo fixtures: 12–16 seeded conversations spanning all JTBD states, 5 KB articles with revisions, 3 GapCandidates, 1 ArticleSuggestion ready for review (Phase 27)
- Customer `/chat` widget wired to real ingress via `Cairnloop.Channels.WidgetSocket` + `WidgetChannel`; two-tab demo (Phase 28)
- Brand-token CSS extraction: `prompts/cairnloop.css` `:root` block in example app; `var(--cl-token)` without hex fallback; negative-grep gate (Phase 29, D-10 closure)
```

---

## Shared Patterns

### Keep a Changelog Standard
**Source:** `CHANGELOG.md`
**Apply to:** `CHANGELOG.md`
Follow strict Keep a Changelog formatting. Summarize phases logically under `### Added`, `### Changed`, `### Fixed`.
When cutting the release, convert `## [Unreleased]` to `## [0.2.0] - YYYY-MM-DD` and add a new `## [Unreleased]` section at the top.

### ExDoc Guide Structure
**Source:** `guides/*.md`
**Apply to:** `guides/05-mcp-clients.md`, `guides/06-extending.md`
All guides start with an H1 title matching the ExDoc config, followed by an introductory paragraph explaining what the guide covers and why. Section headers use H2 (`##`).

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `CONTRIBUTING.md` | documentation | None | No existing contribution guidelines. Standard open-source structure (PR process, local setup, test commands) is needed. |

## Metadata

**Analog search scope:** `guides/`, `docs/`, `CHANGELOG.md`
**Files scanned:** 5
**Pattern extraction date:** 2024-05-29
