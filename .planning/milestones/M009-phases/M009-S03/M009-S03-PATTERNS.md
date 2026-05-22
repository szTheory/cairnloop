# M009-S03 Pattern Map

## Target Files And Closest Analogs

| Planned file | Role | Closest analog | Why it matches |
|---|---|---|---|
| `lib/cairnloop/retrieval.ex` | retrieval-to-draft facade entrypoint | `lib/cairnloop/retrieval.ex` | Existing host-owned retrieval boundary already merges canonical and assistive evidence |
| `lib/cairnloop/retrieval/result.ex` | normalized evidence contract | `lib/cairnloop/retrieval/result.ex` | Already carries source, trust, citation, match-reason, and grounding fields Phase 3 needs to preserve |
| `lib/cairnloop/automation/scoria_engine.ex` | drafting engine boundary | `lib/cairnloop/automation/scoria_engine.ex` | Existing Scoria seam is the place to swap opaque lookup + blob output for structured grounded IO |
| `lib/cairnloop/automation/workers/draft_worker.ex` | async policy junction | `lib/cairnloop/automation/workers/draft_worker.ex` | Already owns telemetry, policy branching, draft creation, and conversation broadcasts |
| `lib/cairnloop/automation/draft.ex` | durable proposal artifact schema | `lib/cairnloop/automation/draft.ex` | Existing persisted draft record should evolve instead of introducing a disconnected transient payload |
| `lib/cairnloop/automation.ex` | draft persistence context | `lib/cairnloop/automation.ex` | Existing `Ecto.Multi` + telemetry workflow is the paved road for storing structured drafts |
| `lib/cairnloop/web/conversation_live.ex` | operator review surface | `lib/cairnloop/web/conversation_live.ex` | Existing evidence rail and draft shell are the correct mounting point for grounded proposal review |
| `lib/cairnloop/web/search_result_presenter.ex` | evidence presentation semantics | `lib/cairnloop/web/search_result_presenter.ex` | Already translates retrieval result semantics into source/trust/copy/open-target labels |
| `test/cairnloop/automation/scoria_engine_test.exs` | engine contract tests | `test/cairnloop/automation/scoria_engine_test.exs` | Existing engine test already stubs remote behavior and asserts returned proposal shape |
| `test/cairnloop/automation/workers/draft_worker_test.exs` | worker branch tests | `test/cairnloop/automation/workers/draft_worker_test.exs` | Existing worker test style already checks policy outcomes, PubSub, and telemetry |
| `test/cairnloop/web/conversation_live_test.exs` | review-surface rendering tests | `test/cairnloop/web/conversation_live_test.exs` | Existing LiveView tests already assert rail copy, draft actions, and shell behavior without full browser plumbing |
| `test/cairnloop/automation_test.exs` | persistence-context tests | `test/cairnloop/automation_test.exs` | Existing tests verify `Ecto.Multi` results and telemetry for draft lifecycle operations |

## Reusable Code Patterns

### 1. Keep retrieval host-owned and reusable by both UI and drafting

From `lib/cairnloop/retrieval.ex`:

```elixir
def search(query, opts \\ []) do
  knowledge_base_results = search_knowledge_base(query, opts)
  resolved_case_results = search_resolved_cases(query, opts)
  ranker(opts).merge(knowledge_base_results, resolved_case_results, opts)
end
```

Phase 3 should extend this boundary or add a sibling retrieval-to-draft function here. Do not let `ScoriaEngine` perform its own remote lookup.

### 2. Reuse the normalized retrieval-result contract instead of inventing draft-only evidence shapes

From `lib/cairnloop/retrieval/result.ex`:

```elixir
defstruct [
  :source_type,
  :trust_level,
  :citation_target,
  :score,
  :can_ground_reply?,
  metadata: %{},
  match_reasons: []
]
```

Grounding snapshots and `evidence[]` entries should preserve these semantics directly, then add operator-facing fields around them only when needed.

### 3. Keep source/trust presentation semantics server-owned and shared

From `lib/cairnloop/web/search_result_presenter.ex`:

```elixir
def source_label(%Result{source_type: :knowledge_base}), do: "Knowledge Base"
def source_label(%Result{source_type: :resolved_case}), do: "Resolved case"

def trust_label(%Result{trust_level: :canonical}), do: "Canonical guidance"
def trust_label(%Result{trust_level: :assistive}), do: "Supporting evidence"
```

The draft evidence rail should echo this exact distinction instead of inventing a new labeling scheme.

### 4. Use durable schema-backed drafts, not ephemeral maps passed straight to the UI

From `lib/cairnloop/automation/draft.ex`:

```elixir
schema "cairnloop_drafts" do
  field(:content, :string)

  field(:status, Ecto.Enum,
    values: [:pending, :approved, :edited, :discarded],
    default: :pending
  )

  belongs_to(:conversation, Cairnloop.Conversation)

  timestamps()
end
```

Phase 3 should evolve this persisted artifact to hold structured proposal and grounding state rather than keeping critical grounding info only in memory.

### 5. Persist draft lifecycle changes through `Ecto.Multi` and emit telemetry at the context boundary

From `lib/cairnloop/automation.ex`:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(
  :draft,
  Draft.changeset(%Draft{}, attrs)
)
|> repo().transaction()
```

```elixir
:telemetry.execute(
  [:cairnloop, :automation, :draft, :created],
  %{count: 1},
  %{draft_id: draft.id}
)
```

Any new grounded-draft create/update helpers should follow this same transaction-first, telemetry-after-success pattern.

### 6. Keep worker branching explicit and observable

From `lib/cairnloop/automation/workers/draft_worker.ex`:

```elixir
case Cairnloop.Automation.ScoriaEngine.generate_draft(conversation_id) do
  {:ok, proposal} ->
    policy =
      Application.get_env(:cairnloop, :automation_policy, Cairnloop.DefaultAutomationPolicy)

    case policy.decide(proposal, %{}) do
      decision when decision in [:draft_only, :require_approval] ->
        handle_create_draft(conversation_id, proposal.content, :pending)

      :allow ->
        handle_create_draft(conversation_id, proposal.content, :approved)

      :deny ->
        :ok
    end
```

Replace the current blob-content branch with explicit grounded outcomes such as normal draft, clarification draft, and escalation recommendation, but keep the branching here visible and testable.

### 7. Keep telemetry spans around worker execution

From `lib/cairnloop/automation/workers/draft_worker.ex`:

```elixir
:telemetry.execute(
  [:openinference, :span, :start],
  %{system_time: start_time},
  %{trace_id: trace_id, span_name: "DraftWorker", span_kind: "AGENT"}
)
```

```elixir
:telemetry.execute(
  [:openinference, :span, :stop],
  %{duration: duration},
  %{status: status}
)
```

Grounding status and weak-grounding reasons should be added as metadata extensions to this existing seam, not emitted from scattered UI code.

### 8. Reuse the existing rail-card review shell in the LiveView

From `lib/cairnloop/web/conversation_live.ex`:

```elixir
<div class="evidence-rail">
  <.context_pane context={@host_context} error={@context_error} actor_id={@conversation.host_user_id} socket={@socket} />
  
  <%= if Ecto.assoc_loaded?(@conversation.drafts) and length(@conversation.drafts) > 0 do %>
    <%= for draft <- @conversation.drafts do %>
      <.draft_audit_card 
        draft={draft} 
        pending_discard_id={@pending_discard_draft_id} 
      />
    <% end %>
  <% end %>
</div>
```

Add a dedicated evidence card adjacent to the draft card in this rail. Do not relocate grounded evidence into the editable reply composer.

### 9. Follow the repo’s rendering style for draft controls

From `lib/cairnloop/web/conversation_live.ex`:

```elixir
<%= if @draft.status in [:pending, :edited] do %>
  <div class="draft-actions">
    <button phx-click="approve_draft" phx-value-draft-id={@draft.id}>Approve & Send</button>
    <button phx-click="edit_draft" phx-value-draft-id={@draft.id}>Apply to Composer</button>
    <button phx-click="discard_draft" phx-value-draft-id={@draft.id}>Discard</button>
  </div>
<% end %>
```

Grounded-draft actions should keep this explicit operator review posture. Clarification and escalation states should still read like review actions, not autonomous send states.

### 10. Reuse test style that asserts the contract, not just presence

From `test/cairnloop/retrieval_test.exs`:

```elixir
assert first.source_type == :knowledge_base
assert first.trust_level == :canonical
assert first.can_ground_reply? == true
assert :kb_source_boost in first.match_reasons
```

New tests should assert exact grounding semantics, proposal type, and evidence labeling rather than only checking that a draft exists.

## File-Specific Guidance

### `lib/cairnloop/retrieval.ex`

- Add the drafting-facing retrieval contract here or in a sibling module under this namespace.
- Prefer returning a canonical-first bundle that keeps KB evidence separate from assistive resolved cases.
- Preserve visibility and tenant filtering before any result becomes draft input.

### `lib/cairnloop/retrieval/result.ex`

- Keep `source_type`, `trust_level`, `citation_target`, `match_reasons`, and `can_ground_reply?` as the backbone of evidence serialization.
- If extra fields are needed for operator evidence display, extend this struct conservatively rather than creating a parallel ad hoc evidence map.

### `lib/cairnloop/automation/scoria_engine.ex`

- Change the function contract from `generate_draft(conversation_id)` to a structured input that accepts the conversation plus grounding bundle.
- Return a structured proposal shape with at least `operator_summary`, `customer_reply`, and `evidence`.
- Keep this module focused on proposal generation, not retrieval, policy decisions, or UI labels.

### `lib/cairnloop/automation/workers/draft_worker.ex`

- Perform retrieval before calling the engine.
- Branch explicitly on grounding status: strong canonical grounding, weak-but-recoverable clarification, and escalation fallback.
- Persist the structured proposal and grounding snapshot together, then broadcast the normal `{:draft_created, draft.id}` event.

### `lib/cairnloop/automation/draft.ex`

- Evolve the schema toward a structured proposal artifact instead of a single `content` blob.
- Preserve compatibility with the existing status lifecycle where possible.
- Store enough durable grounding detail that later telemetry and traces can explain why the proposal is a draft, clarification, or escalation recommendation.

### `lib/cairnloop/automation.ex`

- Add create/update helpers that accept structured proposal attrs and keep persistence decisions centralized here.
- Keep approval/discard/edit semantics host-owned in this context module, not embedded inside the worker or LiveView.

### `lib/cairnloop/web/conversation_live.ex`

- Reuse the current evidence rail and add an always-visible supporting-evidence card next to the draft card.
- Keep `customer_reply` editable in the composer flow and keep `operator_summary` internal to the rail.
- Reuse `SearchResultPresenter` semantics for source label, trust label, recency, and open target.

### `lib/cairnloop/web/search_result_presenter.ex`

- If the planner chooses to reuse this presenter directly for draft evidence, extend it instead of duplicating source/trust/open-path logic elsewhere.
- Keep draft evidence presentation aligned with Phase 2 section labels and trust cues.

### `test/cairnloop/automation/scoria_engine_test.exs`

- Shift assertions from `proposal.content` to the structured proposal fields.
- Add weak-grounding fixtures that verify escalation and clarification outputs are distinct and explicit.

### `test/cairnloop/automation/workers/draft_worker_test.exs`

- Add branch coverage for strong grounding, assistive-only grounding, empty retrieval, retrieval error, and one-shot clarification.
- Continue asserting PubSub broadcast and telemetry start/stop behavior.

### `test/cairnloop/web/conversation_live_test.exs`

- Assert the rail shows separate operator summary, customer reply review shell, and evidence card.
- Assert source label and trust label appear together on each evidence item.
- Assert weak-grounding states do not render a normal confident customer-facing draft body.

### `test/cairnloop/automation_test.exs`

- Add persistence tests around structured attrs and any new draft status or proposal-type fields.
- Keep the existing `MockRepo` + `Ecto.Multi.to_list/1` style for transaction assertions.

## Non-Patterns To Avoid

- Do not keep the current `ScoriaEngine` pattern where it performs its own `Req.get` lookup and returns a single `content` string.
- Do not flatten Knowledge Base and resolved-case evidence into one undifferentiated prompt or UI list.
- Do not let assistive resolved-case evidence alone justify a normal customer-facing policy answer.
- Do not store grounded-draft reasoning only in transient worker variables or UI assigns.
- Do not put inline citation chips or heavy source echoing into the editable reply body by default.
- Do not treat a warning badge on a normal draft as sufficient weak-grounding handling.
- Do not move retrieval, policy branching, and persistence into `ConversationLive`; keep the LiveView as a renderer and event consumer.
- Do not create a second presentation vocabulary for evidence if `SearchResultPresenter` already covers the same semantics.
