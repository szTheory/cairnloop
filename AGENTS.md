# Cairnloop Agent Notes

Read `CLAUDE.md` first. For UI work, also read `docs/operator-ui-principles.md` before editing
`lib/cairnloop/web/**` or `priv/static/cairnloop.css`.

The shipped dashboard uses Cairnloop's tokenized `.cl-*` / BEM CSS system, not Tailwind. Keep
adopter-facing UI changes inside the component system so spacing, motion, color, and accessibility
improve globally instead of drifting screen by screen.
