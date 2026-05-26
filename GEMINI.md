# Cairnloop Project Guidance

## The Conveyor Belt (Milestone Backlog)
We treat our long-term roadmap as a "conveyor belt" of epics to ensure we never start from scratch when planning a new milestone. 

**When instructed to plan a new milestone (e.g. `/gsd-new-milestone`):**
1. **Consult the Backlog:** ALWAYS read `.planning/PROJECT_EPICS.md`.
2. **Pop the Next Epic:** Take the next highest-priority epic off the list to serve as the foundation for the new milestone.
3. **Refill the Belt:** If the list of upcoming epics runs low (2 or fewer remaining), you must autonomously perform a deep domain and architectural synthesis (consulting `prompts/` and `.planning/` artifacts). Generate the next wave of epics—with rigorous pros/cons, ecosystem synergy, and UX/DX tradeoffs—and append them to `.planning/PROJECT_EPICS.md`.

## Automated Discuss Phase
- During `/gsd-discuss-phase` or when making architectural decisions, **DO NOT prompt the user with questions** unless the decision is extremely high-impact or there is no clear technical winner.
- Instead, perform deep architectural research autonomously (including reviewing `prompts/` and `.planning/` artifacts).
- Synthesize one-shot, perfect recommendations. Weigh pros/cons/tradeoffs, consider examples, prioritize idiomatic Elixir/Phoenix/Ecto/Plug patterns, and learn from successful tools in the space.
- Emphasize developer ergonomics, the principle of least surprise, and great UI/UX.
- Output the cohesive recommendations directly to a planning document and conclude the discuss phase.