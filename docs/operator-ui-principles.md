# Cairnloop Operator UI Principles

Cairnloop's dashboard is an embedded operations tool. The default user journey is:

1. **Orient:** Home shows the work queue and the supporting maintenance lanes.
2. **Triage:** Inbox helps an operator pick the next conversation quickly.
3. **Decide:** Conversation keeps the message timeline primary and puts context, KB maintenance,
   outbound recovery, and governed actions in the evidence rail.
4. **Improve:** Knowledge turns conversation evidence into reviewed articles.
5. **Audit:** Audit and Settings explain what happened and how the host app is configured.

## Design System Rules

- Use `priv/static/cairnloop.css` as the visual source of truth. Add or reuse `.cl-*` components
  and BEM-style element classes instead of one-off inline styles.
- Use existing components from `Cairnloop.Web.Components` before creating new markup. Promote
  repeated patterns into shared components or CSS classes.
- Keep spacing, radius, typography, shadow, z-index, color, and motion on `--cl-*` tokens.
- Do not use Tailwind in the shipped library UI. The example host app may use Phoenix defaults for
  its own pages, but mounted Cairnloop dashboard work follows the library CSS system.
- Buttons should look and behave like buttons. Do not add underlined hover text to button labels.
- State is never color alone: pair status color with text and, where useful, an icon.
- Prefer progressive reveal on dense power-user areas. Show the common next action first; keep raw
  details behind native disclosure controls.

## Interaction And Accessibility

- Use native controls first: links navigate, buttons mutate, checkboxes select, and `details`
  discloses.
- Every icon-only control needs an accessible name. Every form field needs a label.
- Keep focus visible, logical, and keyboard reachable.
- Use calm, reason-forward copy. Operators should see what happened, why it matters, and what to do
  next without raw Elixir terms or raw JSON unless they explicitly expand technical details.
- Motion must be purposeful, CSS-only where possible, limited to transform/opacity/color, and
  covered by reduced-motion behavior.

## Testing Expectations

- UI/e2e tests must be deterministic, fast, and non-flaky. Avoid sleeps, network dependency, fixed
  ports, random data without a seed, and assertions coupled to incidental layout trivia.
- Keep high-value happy paths, important error cases, and boundary conditions in automated tests.
- Use screenshots for review and polish, but do not make screenshot capture the sole correctness
  gate. Behavior belongs in ExUnit, integration tests, or targeted Playwright tests.
- Run the focused design gates when changing dashboard UI:
  `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/responsive_markup_test.exs test/cairnloop/web/motion_css_test.exs`.
