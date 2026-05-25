defmodule Cairnloop.Tools.InternalNote do
  @moduledoc """
  Example governed-write tool: appends an operator-only internal note to the
  host-owned `cairnloop_messages` store.

  ## Usage

  This is the Phase 16 proof-of-concept (ACT-01, D16-01) and the reference implementation
  for host developers building governed-write tools. Copy this module and adapt the schema,
  changeset, and `run/3` body.

  ## Design Notes

  - `risk_tier: :low_write` → derives `approval_mode: :requires_approval` automatically (D-09/D-10).
  - `scope/0` returns `[]` — no special scopes required (D16-01: operator-only, low blast radius).
  - `authorize/2` overrides the deny-by-default to `:ok` — any authenticated operator may propose
    this action; the approval gate provides the safety barrier.
  - `run/3` is the ONLY place an actual side effect occurs. It is called only by
    `Cairnloop.Workers.ToolExecutionWorker` after the full approval + re-validation chain (D16-03).
  - Idempotency is implemented via an indexed `run_key` column existence check (D16-05).
    NEVER use a JSONB `metadata:` containment query — Ecto does not emit `@>` for map equality,
    and such a query would bypass the index entirely.
  - The note row carries `role: :internal_note` so it is distinguishable from customer-visible
    messages and can be filtered by host queries (D16-01 "never customer-visible").
  - Repo indirection: `Application.fetch_env!(:cairnloop, :repo)` — never `Cairnloop.Repo`
    directly. The host owns the repo; the library is a guest (D-02 / D16-02).

  ## Run key idempotency

  The worker passes `:run_idempotency_key` in the execution `context`. `run/3` does an
  indexed existence check before inserting. If the row already exists, returns
  `{:ok, %{idempotent: true}}` without inserting — safe under Oban job replay (T-16-01).

  ## Atomicity precondition (WR-01)

  The `run_idempotency_key` passed to `run/3` is attempt-scoped: it is derived from the
  proposal's `idempotency_key` and the current `attempt` number, so a Oban retry gets a
  **different** key. This design allows a retry to proceed cleanly if a prior attempt left
  no evidence row.

  **IMPORTANT for host tool authors copying this module:** your `run/3` MUST be a
  **single atomic write** keyed on `run_key`. If your tool performs multiple writes (e.g.
  row A then row B), a transient failure between them would be retried with a *new*
  `run_idempotency_key` — the existence check for the new key finds nothing, and the
  partial prior write (row A) is not rolled back. This could result in duplicate or
  inconsistent state. Rule: one `run/3` invocation = one atomic operation (one `INSERT`,
  one Ecto.Multi inside a single transaction, etc.).
  """

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

  @impl Cairnloop.Tool
  # No special scopes — any operator-scoped actor may propose this action (D16-01).
  def scope, do: []

  @impl Cairnloop.Tool
  # Override deny-by-default: any authenticated actor may propose an internal note.
  # The approval gate is the safety barrier for this low-blast-radius write (D16-01).
  def authorize(_actor_id, _context), do: :ok

  @impl Cairnloop.Tool
  @doc """
  Appends an `internal_note` role row to `cairnloop_messages`.

  Idempotent on `context[:run_idempotency_key]`: if a row with that `run_key` already
  exists, returns `{:ok, %{idempotent: true}}` without inserting (T-16-01, D16-05).

  Returns:
  - `{:ok, %{message_id: id}}` — note inserted successfully
  - `{:ok, %{idempotent: true}}` — duplicate key; note already written
  - `{:error, changeset}` — insert failed (propagated for Oban retry logic)
  """
  def run(%__MODULE__{conversation_id: conv_id, content: content}, _actor_id, context) do
    repo = Application.fetch_env!(:cairnloop, :repo)
    run_key = Map.get(context, :run_idempotency_key)

    # Idempotency: indexed run_key existence check (D16-05, O(1) via partial unique index).
    # NEVER: repo.get_by(Cairnloop.Message, metadata: %{run_key: run_key})
    # — Ecto does not emit a JSONB @> containment operator for map equality queries;
    #   the above would be either a missing-method error or a full-table scan (documented anti-pattern).
    case run_key && repo.get_by(Cairnloop.Message, run_key: run_key) do
      %Cairnloop.Message{} ->
        # Already written — safe replay; return idempotent ok
        {:ok, %{idempotent: true, note: "already written"}}

      _ ->
        attrs = %{
          conversation_id: conv_id,
          content: content,
          # Distinct role — operator-only, never customer-visible (D16-01)
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
end
