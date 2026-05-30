# Phase 32: README + ExDoc Guides + JTBD Walkthrough - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 32-readme-exdoc-guides-jtbd-walkthrough
**Areas discussed:** Screenshot capture strategy, README restructure extent

---

## Screenshot Capture Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Text-complete + bounded TODO block | Ship complete prose + code references. One bounded `<!-- SCREENSHOTS: ... -->` block at the end, actioned manually in a browser session. Matches Ash/Broadway/Req ecosystem convention. | ✓ |
| Placeholder PNG stubs committed | Commit stub PNGs to `guides/assets/` now, replace with real ones later. Publishes broken images to HexDocs until manually replaced. No Elixir ecosystem precedent. | |

**User's choice:** Text-complete + TODO block (Recommended)
**Notes:** Advisor research confirmed Ash, Broadway, and Req use prose + code — no screenshots in ExDoc guides. Committed stubs would surface broken images to real HexDocs adopters before manual replacement. The bounded `<!-- SCREENSHOTS: ... -->` block gives the owner a clear, contained follow-on action.

---

## README Restructure Extent

| Option | Description | Selected |
|--------|-------------|----------|
| Full restructure | Clean front-door README: `mix cairnloop.install` → short pitch → guide links. Remove "If available in Hex" framing and inlined telemetry docs (those go in `03-host-integration.md`). Matches Beacon/Igniter/Ash pattern. | ✓ |
| Targeted fix only | Swap just the Installation section to lead with `mix cairnloop.install`. Leave existing README content (Mermaid diagram, inlined code, "If available in Hex") in place. | |

**User's choice:** Full restructure (Recommended)
**Notes:** Advisor research confirmed full restructure is correct because guides co-ship in the same phase (no broken-link risk). Current README has two correctness problems: "If [available in Hex]" conditional on a live Hex.pm package, and Installation leading with a bare deps block. Inlined telemetry + Notifier code belongs in `guides/03-host-integration.md`. Mermaid diagram is outdated (predates outbound lane, governed tools, MCP seam) — removing it is cleaner than updating.

---

## Claude's Discretion

All other decisions were auto-decided:
- Guide filenames exactly per DOC-02 requirement (`01-quickstart.md`, `02-jtbd-walkthrough.md`, `03-host-integration.md`, `04-troubleshooting.md`)
- `mix.exs` `extras:` update with `groups_for_extras:` key for ExDoc sidebar grouping
- `mix.exs` `package:` `:files` key added to explicitly include `guides/` in the Hex package
- `docs/cairnloop-jtbd-and-user-flows.md` kept as-is (internal reference, not exposed via ExDoc)
- JTBD walkthrough stage order matches Phase 31 golden-path test sequence
- CHANGELOG vM014 entry format: Keep-a-Changelog `## [Unreleased]` with `### Added` subsection
- `:assets` key omitted from `mix.exs` until real PNGs exist; commented-out placeholder added

## Deferred Ideas

- Real PNG screenshots for `guides/02-jtbd-walkthrough.md` — executor leaves `<!-- SCREENSHOTS: ... -->` block; owner captures in a manual browser session post-delivery
- ExDoc `:assets` config and `guides/assets/` directory — deferred until PNGs exist
- `mix docs` CI gate — not in scope for this phase; noted as a future nice-to-have
- Updating `docs/cairnloop-jtbd-and-user-flows.md` to reflect shipped state — left as internal memo
