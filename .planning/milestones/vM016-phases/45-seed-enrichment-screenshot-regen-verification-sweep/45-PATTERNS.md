# Phase 45: Seed Enrichment + Screenshot Regen + Verification Sweep - Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/cairnloop_example/priv/repo/seeds.exs` | utility | batch + CRUD | `examples/cairnloop_example/priv/repo/seeds.exs` | exact |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | test | batch + CRUD | `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | exact |
| `examples/cairnloop_example/lib/cairnloop_example/tools/high_risk_demo_action.ex` | service | event-driven + request-response | `lib/cairnloop/tools/internal_note.ex` | role-match |
| `examples/cairnloop_example/config/config.exs` | config | config load | `examples/cairnloop_example/config/config.exs` | exact |
| `examples/cairnloop_example/screenshots/capture.mjs` | utility | file-I/O + browser request-response | `examples/cairnloop_example/screenshots/capture.mjs` | exact |
| `examples/cairnloop_example/screenshots/README.md` | docs | file-I/O | `examples/cairnloop_example/screenshots/README.md` | exact |
| `guides/assets/{light,dark}/NN-*.png` or `guides/assets/NN-*-{light,dark}.png` | artifact | file-I/O | `guides/assets/*.png` | role-match |
| `guides/02-jtbd-walkthrough.md` (conditional if asset paths change) | docs | file-I/O | `guides/02-jtbd-walkthrough.md` | exact |
| `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VISUAL-ACCEPTANCE.md` | docs | batch evidence | `.planning/phases/44-motion/44-VERIFICATION.md` | partial |
| `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VERIFICATION.md` | docs | batch verification | `.planning/phases/44-motion/44-VERIFICATION.md` | exact |
| `examples/cairnloop_example/test/e2e/theme_evidence_test.exs` (conditional only if app behavior changes) | test | browser request-response | `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs`, `examples/cairnloop_example/test/e2e/motion_test.exs` | role-match |

## Pattern Assignments

### `examples/cairnloop_example/priv/repo/seeds.exs` (utility, batch + CRUD)

**Analog:** `examples/cairnloop_example/priv/repo/seeds.exs`

**Imports and facade aliases pattern** (lines 70-87):
```elixir
defmodule CairnloopExample.SeedRun do
  alias CairnloopExample.Repo

  alias Cairnloop.Conversation
  alias Cairnloop.Message
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeAutomation.GapCandidateMembership
  alias Cairnloop.Retrieval.GapEvent

  alias Cairnloop.Automation
  alias Cairnloop.Governance
  alias Cairnloop.Workers.{ApprovalResumeWorker, ToolExecutionWorker}
```

**Builder ordering pattern** (lines 93-105):
```elixir
def run do
  IO.puts("Seeding Cairnloop example app demo data...")

  articles = build_articles()
  conversations = build_conversations(articles)
  showcase = build_showcase_states()
  gaps = build_gaps(conversations)
  {suggestion, _review_task} = build_suggestion(articles, conversations)

  drain_summary = drain_embedding_pipeline()

  emit_seed_summary(articles, conversations ++ showcase, gaps, suggestion, drain_summary)
  :ok
end
```

**KnowledgeBase facade pattern** (lines 120-164):
```elixir
# Each article is created via the KnowledgeBase facade (D-09):
#   get_or_insert!(Article, :title, ...) for the article row,
#   KnowledgeBase.save_draft/2 + KnowledgeBase.publish_revision/1 for each revision.
# publish_revision/1 is the load-bearing call that enqueues ChunkRevision into Oban (FIX-02).
defp build_articles do
  import Ecto.Query

  api_key_article =
    get_or_insert!(Article, :title, %{
      title: "Resetting your Trailmark API key",
      status: :draft
    })

  unless Repo.one(
           from r in Revision,
             where: r.article_id == ^api_key_article.id and r.state == :published,
             limit: 1
         ) do
    {:ok, draft} = KnowledgeBase.save_draft(api_key_article, %{content: body})
    {:ok, _published} = KnowledgeBase.publish_revision(draft)
  end
end
```

**ReviewTask companion pattern** (lines 1216-1246):
```elixir
suggestion =
  case Repo.get_by(ArticleSuggestion, stable_key: @demo_suggestion_stable_key) do
    nil ->
      %ArticleSuggestion{}
      |> ArticleSuggestion.changeset(suggestion_attrs)
      |> Repo.insert!()

    existing ->
      existing
  end

{:ok, review_task} =
  KnowledgeAutomation.ensure_review_task_for_suggestion(
    suggestion.id,
    actor_id: "system"
  )

{suggestion, review_task}
```

**Governed-action facade pattern** (lines 1389-1448):
```elixir
{:ok, proposal} =
  Governance.propose(@internal_note_ref, @showcase_operator, %{
    conversation_id: to_string(conv.id),
    scopes: [],
    tool_params: %{conversation_id: to_string(conv.id), content: content}
  })

{:ok, approval} = Governance.request_approval(proposal, enqueue_fn: &noop_enqueue/1)

{:ok, _approved} =
  Governance.approve(approval.id, @showcase_operator, enqueue_fn: &noop_enqueue/1)

:ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

:ok =
  ToolExecutionWorker.perform(%Oban.Job{
    attempt: 1,
    max_attempts: 3,
    args: %{"approval_id" => approval.id}
  })
```

**Oban drain and warning pattern** (lines 1274-1294):
```elixir
defp drain_embedding_pipeline do
  IO.puts("Draining embedding pipeline (Oban :default queue)...")

  %{success: success, failure: failure} =
    result =
    Oban.drain_queue(queue: :default, with_recursion: true)

  if failure > 0 do
    IO.warn(
      "Seed embedding pipeline drained with #{failure} failures. " <>
        "Inspect oban_jobs.errors for details."
    )
  end

  IO.puts("Drained #{success} embedding job(s).")
  result
end
```

**Natural-key idempotency helper** (lines 1534-1549):
```elixir
defp get_or_insert!(schema_module, natural_key_field, attrs) do
  case Repo.get_by(schema_module, [{natural_key_field, Map.fetch!(attrs, natural_key_field)}]) do
    nil ->
      struct(schema_module)
      |> schema_module.changeset(attrs)
      |> Repo.insert!()

    existing ->
      existing
  end
end
```

**Apply to Phase 45:**
- Add small helper builders in this same script before the final `get_or_insert!/3` helper.
- Use stable natural keys such as names, `stable_key`, or `[demo-NN]` subjects.
- Use facades first: `KnowledgeAutomation`, `KnowledgeBase`, `Governance`, and `MCP`.
- Use direct DB updates only for seed-owned passive presentation fields such as timestamps or display ordering, with short seed-only comments.

---

### `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` (test, batch + CRUD)

**Analog:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs`

**Imports and DB contract pattern** (lines 1-26):
```elixir
defmodule CairnloopExample.SeedsTest do
  use CairnloopExample.DataCase, async: false

  @moduletag :requires_postgres

  alias Cairnloop.Conversation
  alias Cairnloop.Message
  alias Cairnloop.Automation.Draft
  alias Cairnloop.Governance.ToolActionEvent
  alias Cairnloop.Governance.ToolApproval
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Chunk
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeAutomation.GapCandidateMembership
  alias Cairnloop.KnowledgeAutomation.ReviewTask

  import Ecto.Query
```

**Seed execution helper** (lines 28-46):
```elixir
defp run_seed!() do
  seed_path = Path.expand("../../priv/repo/seeds.exs", __DIR__)
  assert File.exists?(seed_path), "seed file not found at resolved path: #{seed_path}"
  Code.eval_file(seed_path)
  :ok
end
```

**State coverage assertions pattern** (lines 174-204):
```elixir
test "seeds the frozen showcase states for JTBD stages 4/5/6/8" do
  assert :ok == run_seed!()

  assert Repo.aggregate(from(d in Draft, where: d.status == :pending), :count) >= 1
  assert Repo.aggregate(from(a in ToolApproval, where: a.status == :pending), :count) >= 1
  assert Repo.aggregate(from(a in ToolApproval, where: a.status == :executed), :count) >= 1
  assert Repo.aggregate(ToolActionEvent, :count) >= 1

  assert Repo.aggregate(
           from(m in Message, where: m.role == :internal_note and not is_nil(m.run_key)),
           :count
         ) >= 1

  assert Repo.aggregate(from(m in Message, where: m.role == :system_outbound), :count) >= 1
end
```

**Idempotency regression pattern** (lines 209-248):
```elixir
test "D-02 idempotency: running the seed twice produces stable row counts" do
  assert :ok == run_seed!()

  counts_after_run_1 = %{
    conversations: Repo.aggregate(Conversation, :count),
    messages: Repo.aggregate(Message, :count),
    articles: Repo.aggregate(Article, :count),
    revisions: Repo.aggregate(Revision, :count),
    gap_candidates: Repo.aggregate(GapCandidate, :count),
    memberships: Repo.aggregate(GapCandidateMembership, :count),
    suggestions: Repo.aggregate(ArticleSuggestion, :count),
    review_tasks: Repo.aggregate(ReviewTask, :count),
    drafts: Repo.aggregate(Draft, :count),
    approvals: Repo.aggregate(ToolApproval, :count),
    action_events: Repo.aggregate(ToolActionEvent, :count)
  }

  assert :ok == run_seed!()
  assert counts_after_run_1 == counts_after_run_2
end
```

**Apply to Phase 45:**
- Extend aliases for `Cairnloop.MCP.Token` and any example-only high-risk tool evidence.
- Add assertions for rejected/deferred governed approvals, varied event timestamps/reasons, rejected/deferred/published ReviewTask states, one draft article/revision, active MCP token rows, and masked Settings output where feasible.
- Add new counts to both idempotency maps so repeated seeds prove no duplicate tokens, tasks, approvals, events, or articles.

---

### `examples/cairnloop_example/lib/cairnloop_example/tools/high_risk_demo_action.ex` (service, event-driven + request-response)

**Analog:** `lib/cairnloop/tools/internal_note.ex`

**Tool declaration and input validation pattern** (lines 50-66):
```elixir
use Cairnloop.Tool,
  risk_tier: :low_write,
  title: "Add internal note",
  description: "Appends an operator-only note to the conversation thread."

embedded_schema do
  field(:conversation_id, :string)
  field(:content, :string)
end

@impl Cairnloop.Tool
def changeset(struct, attrs) do
  struct
  |> cast(attrs, [:conversation_id, :content])
  |> validate_required([:conversation_id, :content])
  |> validate_length(:content, min: 1, max: 5_000)
end
```

**Scope, authorization, and side-effect pattern** (lines 68-116):
```elixir
@impl Cairnloop.Tool
def scope, do: []

@impl Cairnloop.Tool
def authorize(_actor_id, _context), do: :ok

@impl Cairnloop.Tool
def run(%__MODULE__{conversation_id: conv_id, content: content}, _actor_id, context) do
  repo = Application.fetch_env!(:cairnloop, :repo)
  run_key = Map.get(context, :run_idempotency_key)

  case run_key && repo.get_by(Cairnloop.Message, run_key: run_key) do
    %Cairnloop.Message{} ->
      {:ok, %{idempotent: true, note: "already written"}}

    _ ->
      attrs = %{
        conversation_id: conv_id,
        content: content,
        role: :internal_note,
        run_key: run_key,
        metadata: %{source: "cairnloop_governed_action", run_key: run_key}
      }

      case repo.insert(Cairnloop.Message.changeset(%Cairnloop.Message{}, attrs)) do
        {:ok, msg} -> {:ok, %{message_id: msg.id}}
        {:error, cs} -> {:error, cs}
      end
  end
end
```

**Risk-tier derivation source** (`lib/cairnloop/tool.ex`, lines 124-139):
```elixir
def derive_approval_mode(:read_only), do: :auto
def derive_approval_mode(:low_write), do: :requires_approval
def derive_approval_mode(:high_write), do: :requires_approval
def derive_approval_mode(:destructive), do: :always_block
def derive_approval_mode(_), do: :always_block
```

**Apply to Phase 45:**
- Only create this module if `InternalNote` cannot show the required higher-risk approval state clearly.
- Use `risk_tier: :high_write` with normal approval-required behavior.
- Keep the module under `examples/cairnloop_example/lib/...`, not `lib/cairnloop/...`.
- Make `run/3` a no-op or one atomic benign write; do not add real destructive behavior.

---

### `examples/cairnloop_example/config/config.exs` (config, config load)

**Analog:** `examples/cairnloop_example/config/config.exs`

**Existing tool registration pattern** (lines 63-71):
```elixir
config :cairnloop,
  repo: CairnloopExample.Repo,
  tools: [Cairnloop.Tools.InternalNote],
  context_provider: CairnloopExample.DemoContextProvider,
  auditor: Cairnloop.Auditor.Governance
```

**Apply to Phase 45:**
- If an example-only high-risk tool is created, add it to the `tools:` list beside `Cairnloop.Tools.InternalNote`.
- Keep the repo, context provider, and auditor wiring unchanged.
- Do not register the demo tool from the library root config.

---

### `examples/cairnloop_example/screenshots/capture.mjs` (utility, file-I/O + browser request-response)

**Analog:** `examples/cairnloop_example/screenshots/capture.mjs`

**Imports and output directory pattern** (lines 17-24):
```javascript
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdir } from "node:fs/promises";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "..", "..", "..", "guides", "assets");
const BASE_URL = (process.env.BASE_URL || "http://localhost:4000").replace(/\/$/, "");
```

**Motion stabilization pattern** (lines 29-39):
```javascript
const STABILIZE_CSS = `
  *, *::before, *::after {
    animation-duration: 0s !important;
    animation-delay: 0s !important;
    transition-duration: 0s !important;
    transition-delay: 0s !important;
    caret-color: transparent !important;
    scroll-behavior: auto !important;
  }
`;
```

**Shot matrix pattern** (lines 44-106):
```javascript
const SHOTS = [
  { file: "02-cockpit-home.png", path: "/support", waitFor: "text=Welcome back", fullPage: true },
  { file: "02b-operator-inbox.png", path: "/support/inbox", waitFor: "text=Inbox", fullPage: true },
  { file: "03-conversation-workspace.png", path: "/support/1", waitFor: ".message-card", fullPage: true },
  { file: "04-approve-draft.png", path: "/support/17", waitFor: "text=Approve & Send", fullPage: true },
  { file: "05-action-pending.png", path: "/support/18", waitFor: ".message-card", fullPage: true },
  { file: "06-action-executed.png", path: "/support/19", waitFor: "text=Action completed", fullPage: true },
  { file: "12-audit-log.png", path: "/support/audit-log", waitFor: "text=Audit Log", fullPage: true },
  { file: "13-settings.png", path: "/support/settings", waitFor: "body", fullPage: true },
];
```

**Browser context and screenshot loop pattern** (lines 119-163):
```javascript
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: VIEWPORT,
  deviceScaleFactor: DEVICE_SCALE,
  reducedMotion: "reduce",
  colorScheme: "light",
});
await context.addInitScript((css) => {
  const style = document.createElement("style");
  style.textContent = css;
  document.documentElement.appendChild(style);
}, STABILIZE_CSS);

for (const shot of SHOTS) {
  await page.goto(url, { waitUntil: "networkidle", timeout: 20000 });
  await waitForLiveViewConnected(page);
  await page.locator(shot.waitFor).first().waitFor({ state: "visible", timeout: 8000 });
  if (shot.prepare) await shot.prepare(page);
  await page.waitForTimeout(150);
  await page.screenshot({
    path: join(OUT_DIR, shot.file),
    fullPage: Boolean(shot.fullPage),
  });
}
```

**App theme state source** (`lib/cairnloop/web/settings_live.ex`, lines 159-162):
```elixir
onclick="document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'; localStorage.setItem('phx:theme', document.documentElement.dataset.theme); window.dispatchEvent(new CustomEvent('phx:set-theme'));"
```

**Apply to Phase 45:**
- Keep this capture-only and non-gating.
- Loop explicit themes, e.g. `[{name: "light", colorScheme: "light"}, {name: "dark", colorScheme: "dark"}]`.
- For each context, set both `colorScheme` and app state before navigation: `localStorage.setItem("phx:theme", themeName)` and `document.documentElement.dataset.theme = themeName`.
- Write theme-explicit filenames or directories. Prefer theme directories for many screenshots, e.g. `guides/assets/light/02-cockpit-home.png` and `guides/assets/dark/02-cockpit-home.png`.
- Keep customer chat and demo index outside the Phase 45 acceptance ledger unless docs still need them regenerated.

---

### `examples/cairnloop_example/screenshots/README.md` (docs, file-I/O)

**Analog:** `examples/cairnloop_example/screenshots/README.md`

**Non-gating capture posture** (lines 6-10):
```markdown
This is a **capture-only, non-gating** tool. It drives a real browser to take pictures; it asserts
nothing and is deliberately kept out of CI's gating lane. The project's locked decision - _no Wallaby,
no browser assertions in CI (Chrome-in-CI flake is real)_ - is unchanged: the deterministic
`test/integration/golden_path_test.exs` (`Phoenix.LiveViewTest`) remains the single source of CI truth.
A drifted screenshot can never break a build.
```

**Usage pattern** (lines 19-31):
```markdown
mix ecto.reset
mix phx.server                      # PORT=4010 mix phx.server  if 4000 is taken

cd screenshots
npm install
BASE_URL=http://localhost:4000 npm run capture     # match your PORT
```

**Determinism checklist** (lines 33-42):
```markdown
- Fixed viewport (1440x900) and device scale (2x).
- Reduced motion + an injected stylesheet that disables animations, transitions, and caret blink.
- Each shot waits on the LiveView being connected and a concrete target selector - never on sleeps.
- Capturing from the idempotent seed (`mix ecto.reset`) means a fixed dataset every run.
```

**Apply to Phase 45:**
- Update docs to mention explicit light and dark output paths.
- Keep the capture command and non-gating language.
- Mention that screenshots are evidence assets, while behavior remains covered by tests.

---

### `guides/assets/{light,dark}/NN-*.png` or `guides/assets/NN-*-{light,dark}.png` (artifact, file-I/O)

**Analog:** existing `guides/assets/*.png`

**Current asset set:**
```text
guides/assets/02-cockpit-home.png
guides/assets/02b-operator-inbox.png
guides/assets/03-conversation-workspace.png
guides/assets/04-approve-draft.png
guides/assets/05-action-pending.png
guides/assets/06-action-executed.png
guides/assets/07-resolved-conversation.png
guides/assets/08-outbound-recovery.png
guides/assets/09-bulk-recovery.png
guides/assets/10-knowledge-base.png
guides/assets/11-knowledge-gaps.png
guides/assets/11b-kb-suggestions.png
guides/assets/11c-kb-editor.png
guides/assets/12-audit-log.png
guides/assets/13-settings.png
```

**Apply to Phase 45:**
- Generate operator/admin state captures in both light and dark themes.
- Make the theme visible from path or filename.
- Keep screenshot file names stable enough for the visual acceptance ledger to reference directly.
- Treat image binaries as generated artifacts from `capture.mjs`.

---

### `guides/02-jtbd-walkthrough.md` (conditional docs, file-I/O)

**Analog:** `guides/02-jtbd-walkthrough.md`

**Current screenshot reference pattern** (lines 14-17, 243-247):
```markdown
![Cairnloop demo index - the Trailmark scenario and a guided tour of all nine JTBD stages](assets/00-demo-index.png)

> The screenshots in this guide are captured from the seeded example app. To refresh them, see
> `examples/cairnloop_example/screenshots/`.

> **Refreshing these screenshots:** boot the seeded example app
> (`cd examples/cairnloop_example && mix ecto.reset && mix phx.server`) and run the capture tool in
> `examples/cairnloop_example/screenshots/` (`npm install && npm run capture`). It drives the demo
> with Playwright and rewrites `guides/assets/`.
```

**Apply to Phase 45:**
- Modify only if the chosen screenshot layout changes docs-visible filenames.
- Do not add Phase 45 visual acceptance content here; keep that in `45-VISUAL-ACCEPTANCE.md`.
- Keep customer chat/demo index references only for docs continuity, not Phase 45 acceptance scope.

---

### `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VISUAL-ACCEPTANCE.md` (docs, batch evidence)

**Analog:** `.planning/phases/44-motion/44-VERIFICATION.md`

**Compact verification artifact pattern** (lines 1-16):
```markdown
# Phase 44 Verification

Completed: 2026-06-26

## Commands Run

- `mix format ...`
- `mix test ...` - 42 tests, 0 failures.
- `mix compile --warnings-as-errors` - clean.
- `cd examples/cairnloop_example && mix test.e2e test/e2e/motion_test.exs` - 2 tests, 0 failures.
- `mix test` - 1 doctest, 1057 tests, 0 failures, 57 excluded.
```

**Recommended Phase 45 ledger pattern:**
```markdown
# Phase 45 Visual Acceptance

Completed: 2026-06-26

| Screen | Theme | Screenshot | Result | Notes |
|--------|-------|------------|--------|-------|
| Cockpit home | light | `guides/assets/light/02-cockpit-home.png` | Pass | Brand tokens, hierarchy, no overlap. |
| Cockpit home | dark | `guides/assets/dark/02-cockpit-home.png` | Pass | Dark theme is intentional, no stale palette. |
```

**Apply to Phase 45:**
- One row per captured screen and theme.
- Include screenshot path, pass/fail, and short notes.
- Notes should cover brand tokens/logo, light/dark correctness, state visible beyond color, hierarchy/density, calm user-facing copy, conventional focus/tap affordances, no backend leakage, and no stale gradients/palettes/assets.

---

### `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VERIFICATION.md` (docs, batch verification)

**Analog:** `.planning/phases/44-motion/44-VERIFICATION.md`

**Commands-run format** (lines 5-16):
```markdown
## Commands Run

- `mix test test/cairnloop/web/motion_css_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/brand_token_gate_test.exs` - 42 tests, 0 failures.
- `mix compile --warnings-as-errors` - clean.
- `cd examples/cairnloop_example && mix test.e2e test/e2e/motion_test.exs` - 2 tests, 0 failures.
- `mix test` - 1 doctest, 1057 tests, 0 failures, 57 excluded.
```

**Apply to Phase 45:**
- Record focused checks while working.
- Before green, record the full sweep from context: root `mix test`, root `PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration`, root `mix check`, example `PGPORT=5432 MIX_ENV=test mix test.e2e`, screenshot regeneration, and release-gate/milestone audit review.
- Include failures honestly with the failing command and key output.

---

### `examples/cairnloop_example/test/e2e/theme_evidence_test.exs` (conditional test, browser request-response)

**Analog:** `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs` and `examples/cairnloop_example/test/e2e/motion_test.exs`

**PhoenixTest Playwright case pattern** (`rail_disclosure_test.exs`, lines 15-24):
```elixir
The Ecto sandbox is managed by PhoenixTest.Playwright.Case; the dashboard live_session joins it
via CairnloopExampleWeb.LiveAcceptance (test-only on_mount), so the fixture's data is visible to
the rendered (library-owned) ConversationLive.
"""
use PhoenixTest.Playwright.Case, async: false

@moduletag :e2e

import CairnloopExample.RailFixtures
```

**localStorage/browser state assertion pattern** (`rail_disclosure_test.exs`, lines 62-89):
```elixir
test "toggling flips data-density, persists to localStorage, and survives reload", %{conn: conn} do
  conn =
    conn
    |> visit("/support/#{conv_id}")
    |> assert_has("body .phx-connected")
    |> assert_has("#evidence-rail-density[data-density='comfortable']")

  conn =
    conn
    |> click_button("Comfortable")
    |> assert_has("#evidence-rail-density[data-density='compact']")

  evaluate(conn, "window.localStorage.getItem('cl:rail:density')", fn value ->
    assert value == "compact"
  end)

  conn
  |> reload()
  |> assert_has("body .phx-connected")
  |> assert_has("#evidence-rail-density[data-density='compact']")
end
```

**Browser context opts pattern** (`motion_test.exs`, lines 107-114):
```elixir
use PhoenixTest.Playwright.Case,
  async: false,
  browser_context_opts: [
    viewport: %{width: 1024, height: 720},
    reduced_motion: :reduce
  ]

@moduletag :e2e
```

**Apply to Phase 45:**
- Add this only if implementation changes app theme behavior, geometry, focus, navigation, or motion.
- Do not add an E2E just to assert screenshot bytes.
- If added, assert browser-visible behavior such as `document.documentElement.dataset.theme`, localStorage key, and visible dark/light rendering cues.

## Shared Patterns

### Facade-First Seed State

**Sources:** `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/knowledge_automation.ex`, `lib/cairnloop/governance.ex`, `lib/cairnloop/mcp.ex`

**KnowledgeBase save/publish facade** (`lib/cairnloop/knowledge_base.ex`, lines 46-108):
```elixir
def save_draft(article, content_attrs) do
  latest = get_latest_revision(article.id)
  attrs = Enum.into(content_attrs, %{})

  multi =
    if latest && latest.state == :draft do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:revision, Revision.changeset(latest, attrs))
    else
      version = if latest, do: latest.version + 1, else: 1
      new_attrs = Map.merge(attrs, %{article_id: article.id, version: version, state: :draft})

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:revision, Revision.changeset(%Revision{}, new_attrs))
    end

  multi
  |> repo().transaction()
end

def publish_revision(revision) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
  |> Ecto.Multi.update(:article, fn %{revision: rev} ->
    Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
  end)
  |> Ecto.Multi.insert(
    :chunk_job,
    Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id})
  )
  |> repo().transaction()
end
```

**Apply to:** `seeds.exs`, `seeds_test.exs`, visual screenshot state setup.

### ReviewTask State Ownership

**Sources:** `lib/cairnloop/knowledge_automation.ex`, `lib/cairnloop/knowledge_automation/review_task.ex`

**Status ordering and creation** (`lib/cairnloop/knowledge_automation.ex`, lines 125-213):
```elixir
def list_review_tasks(opts \\ []) do
  ReviewTask
  |> apply_scope(opts)
  |> maybe_filter_review_task_status(opts)
  |> order_by([task],
    asc:
      fragment(
        """
        CASE ?
          WHEN 'pending_review' THEN 0
          WHEN 'review_needed' THEN 1
          WHEN 'approved_ready_to_publish' THEN 2
          WHEN 'deferred' THEN 3
          WHEN 'rejected' THEN 4
          WHEN 'published' THEN 5
          ELSE 6
        END
        """,
        task.status
      ),
    desc: task.inserted_at,
    desc: task.id
  )
  |> repo().all()
end

def ensure_review_task_for_suggestion(id, opts \\ []) do
  actor_id = Keyword.get(opts, :actor_id)
  suggestion = get_article_suggestion!(id, opts)

  ensure_review_task_for_loaded_suggestion(suggestion, actor_id, opts)
end
```

**Decision functions** (`lib/cairnloop/knowledge_automation.ex`, lines 293-319):
```elixir
def reject_review_task(id, opts \\ []) do
  with reason when is_atom(reason) <- Keyword.get(opts, :reason),
       true <- ReviewTask.valid_reason_for_decision?(:rejected, reason) do
    record_structured_decision(id, :rejected, :rejected, reason, opts)
  else
    _ -> {:error, :invalid_reason}
  end
end

def defer_review_task(id, opts \\ []) do
  with reason when is_atom(reason) <- Keyword.get(opts, :reason),
       true <- ReviewTask.valid_reason_for_decision?(:deferred, reason) do
    record_structured_decision(id, :deferred, :deferred, reason, opts)
  else
    _ -> {:error, :invalid_reason}
  end
end

def publish_review_task(id, opts \\ []) do
  ...
end
```

**Allowed ReviewTask states and reasons** (`lib/cairnloop/knowledge_automation/review_task.ex`, lines 8-26, 124-133):
```elixir
@status_values [
  :pending_review,
  :review_needed,
  :approved_ready_to_publish,
  :deferred,
  :rejected,
  :published
]

def valid_reason_for_decision?(:rejected, reason),
  do: reason in [:insufficient_evidence, :policy_rejected]

def valid_reason_for_decision?(:deferred, reason),
  do: reason in [:needs_manual_edit, :operator_deferred]
```

**Apply to:** knowledge suggestion seeds and seed tests. Do not invent `ArticleSuggestion` statuses.

### Governance Audit Event State

**Source:** `lib/cairnloop/governance.ex`

**Proposal co-commit** (lines 288-407):
```elixir
def propose(tool_ref, actor_id, context) do
  case validate(tool_ref, actor_id, context) do
    {:ok, validated} ->
      propose_valid(tool_ref, actor_id, context, validated)

    {:blocked, :unsupported, _reason} = blocked ->
      Telemetry.emit(:proposal_blocked, %{count: 1}, %{outcome: :unsupported})
      blocked

    {:blocked, outcome, reason} = blocked ->
      case propose_blocked(tool_ref, actor_id, context, outcome, reason) do
        :ok -> blocked
        {:error, _cs} = err -> err
      end
  end
end

with {:ok, proposal} <- %ToolProposal{} |> ToolProposal.changeset(proposal_attrs) |> repo().insert(),
     {:ok, _event} <- %ToolActionEvent{} |> ToolActionEvent.changeset(%{tool_proposal_id: proposal.id, event_type: :proposal_created}) |> repo().insert() do
  {:ok, proposal}
end
```

**Reject/defer reason requirement** (lines 756-865):
```elixir
def reject(approval_id, actor_id, opts \\ []) do
  reason = Keyword.get(opts, :reason)

  case repo().get(ToolApproval, approval_id) do
    %ToolApproval{status: :pending} = approval ->
      changeset =
        ToolApproval.decision_changeset(
          approval,
          :rejected,
          "rejected",
          reason,
          actor_id,
          DateTime.utc_now()
        )

      if changeset.valid? do
        update_approval_with_event(approval, changeset, event_attrs)
      else
        {:error, changeset}
      end

    %ToolApproval{} ->
      {:error, :not_pending}
  end
end
```

**Audit log read facade** (lines 985-1012):
```elixir
def list_action_events(opts \\ []) do
  limit = Keyword.get(opts, :limit, 100)
  offset = Keyword.get(opts, :offset, 0)
  proposal_id = Keyword.get(opts, :proposal_id)

  ToolActionEvent
  |> maybe_where_proposal(proposal_id)
  |> order_by([e], desc: e.inserted_at, desc: e.id)
  |> limit(^limit)
  |> offset(^offset)
  |> preload(:tool_proposal)
  |> repo().all()
end
```

**Apply to:** rejected/deferred governed-action seeds, audit chronology tweaks, audit log screenshots, seed tests.

### MCP Token Safety

**Sources:** `lib/cairnloop/mcp.ex`, `lib/cairnloop/web/settings_live.ex`

**Issue and discard raw token in seeds** (`lib/cairnloop/mcp.ex`, lines 11-29):
```elixir
@doc """
Issues a new token.
Returns `{:ok, token_record, raw_token_string}` on success.
"""
def issue_token(attrs \\ %{}) do
  raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  token_hash = :crypto.hash(:sha256, raw_token)

  attrs = Map.put(attrs, :token_hash, token_hash)
  attrs = Map.put_new(attrs, :name, "MCP Token")

  %Token{}
  |> Token.changeset(attrs)
  |> repo().insert()
  |> case do
    {:ok, token} -> {:ok, token, raw_token}
    {:error, changeset} -> {:error, changeset}
  end
end
```

**Masked Settings display** (`lib/cairnloop/web/settings_live.ex`, lines 200-218):
```elixir
<.cl_banner :if={@new_raw_token} variant="warning" class="cl-mb-7">
  <strong>Copy your new token now.</strong> It will not be shown again.
  <code class="cl-code-block cl-mt-5">{@new_raw_token}</code>
</.cl_banner>

<ul :if={not Enum.empty?(@tokens)} class="cl-stack">
  <li :for={token <- @tokens} class="cl-row cl-row--between cl-list-row">
    <div class="cl-stack">
      <form phx-submit="update_token" class="cl-row">
        <input type="text" name="name" value={token.name} required class="cl-input" />
      </form>
      <span class="cl-text-muted cl-text-small cl-mono">cl_mcp_***</span>
    </div>
  </li>
</ul>
```

**Apply to:** MCP token seeds and Settings screenshot assertions. Bind raw token as `_raw_token` and never log, assert, or include it in artifacts.

### Screenshot Evidence, Not Pixel Gate

**Sources:** `examples/cairnloop_example/screenshots/capture.mjs`, `examples/cairnloop_example/screenshots/README.md`, `examples/cairnloop_example/screenshots/package.json`

**Package script pattern** (`package.json`, lines 7-13):
```json
"scripts": {
  "capture": "playwright install chromium --with-deps && node capture.mjs",
  "capture:no-install": "node capture.mjs"
},
"devDependencies": {
  "playwright": "^1.49.0"
}
```

**Apply to:** screenshot regeneration. Do not add Percy, Chromatic, Storybook, or CI pixel gates. Do not upgrade Playwright during this phase.

### Verification Sweep

**Root aliases** (`mix.exs`, lines 84-100):
```elixir
"test.setup": [
  "ecto.create --quiet -r Cairnloop.Repo -r Chimeway.Repo",
  "ecto.migrate --quiet --migrations-path priv/test_host/migrations --migrations-path priv/repo/migrations"
],
"test.integration": ["test.setup", "test --include integration test/integration"],
check: [
  "format --check-formatted",
  "compile --warnings-as-errors",
  "credo --strict",
  "docs --warnings-as-errors",
  "deps.audit"
]
```

**Example E2E alias** (`examples/cairnloop_example/mix.exs`, lines 124-137):
```elixir
"test.e2e": [
  "assets.setup",
  "assets.build",
  "ecto.create --quiet",
  "ecto.migrate --quiet",
  reenable_migrate,
  "ecto.migrate --migrations-path #{cairnloop_migrations} --quiet",
  "test --only e2e"
]
```

**CI release gate** (`.github/workflows/ci.yml`, lines 243-271):
```yaml
release_gate:
  name: release_gate
  needs: [phase-12-shift-left, integration, quality, e2e]
  if: ${{ always() }}
  steps:
    - name: Gate on required jobs
      run: |
        if [ "${{ needs.phase-12-shift-left.result }}" != "success" ]; then
          exit 1
        fi
        if [ "${{ needs.integration.result }}" != "success" ]; then
          exit 1
        fi
        if [ "${{ needs.quality.result }}" != "success" ]; then
          exit 1
        fi
        if [ "${{ needs.e2e.result }}" != "success" ]; then
          exit 1
        fi
```

**Apply to:** `45-VERIFICATION.md` and final phase gate. Keep `PGPORT=5432` explicit in local integration/E2E commands.

## No Exact Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-VISUAL-ACCEPTANCE.md` | docs | batch evidence | No prior compact per-screen dual-theme visual acceptance ledger exists. Use the Phase 44 verification format plus the Phase 45 D-11 checklist. |
| `guides/assets/{light,dark}/NN-*.png` or `guides/assets/NN-*-{light,dark}.png` | artifact | file-I/O | Existing screenshots are single-theme. Use the current asset naming and `capture.mjs` shot matrix as the base, but make theme explicit. |
| `examples/cairnloop_example/lib/cairnloop_example/tools/high_risk_demo_action.ex` | service | event-driven + request-response | Existing governed tool lives in the library namespace and is `:low_write`; copy the behavior shape from `InternalNote`, but keep the Phase 45 high-risk demo module example-app-only. |

## Metadata

**Analog search scope:** `examples/cairnloop_example`, `lib/cairnloop`, `test`, `guides`, `.planning/phases`, `.github/workflows`
**Files scanned:** 405 via `rg --files`
**Primary analogs read:** `seeds.exs`, `seeds_test.exs`, `capture.mjs`, screenshot `README.md`, `InternalNote`, example `config.exs`, `KnowledgeAutomation`, `ReviewTask`, `Governance`, `MCP`, `SettingsLive`, E2E tests, Mix aliases, CI, Phase 44 verification
**Pattern extraction date:** 2026-06-26
