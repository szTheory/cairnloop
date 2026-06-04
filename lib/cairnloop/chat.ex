defmodule Cairnloop.Chat do
  import Ecto.Query
  alias Cairnloop.{Conversation, Message}
  alias Cairnloop.Conversations.SLA

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def list_conversations do
    Conversation
    |> order_by(desc: :updated_at)
    |> repo().all()
  end

  # Phase 39 Plan 01 (D-02, HOME-02): status-scoped read.
  # Additive sibling clause — the sealed 0-arity clause above is preserved verbatim.
  # opts: [status: :open | :resolved | :archived | nil | unknown_atom]
  # Unknown/nil status falls through scope_status/2 to the unscoped query (D-03 defense-in-depth).
  def list_conversations(opts) when is_list(opts) do
    Conversation
    |> order_by(desc: :updated_at)
    |> scope_status(Keyword.get(opts, :status))
    |> repo().all()
  end

  # Phase 39 Plan 01 (D-09, HOME-05): cheap SELECT count(*) — never a full list load + Enum.count.
  # opts: [status: :open | :resolved | :archived | nil | unknown_atom]
  def count_conversations(opts \\ []) do
    Conversation
    |> scope_status(Keyword.get(opts, :status))
    |> repo().aggregate(:count, :id)
  end

  # Private where-builder shared by list_conversations/1 and count_conversations/1.
  # Single source of truth so list and count can never disagree.
  # Three clauses:
  #   nil        → unscoped (passthrough)
  #   known atom → where c.status == ^status (parameterized pin, no string interpolation)
  #   unknown    → unscoped (D-03 defense-in-depth; never crash on bad input)
  defp scope_status(query, nil), do: query

  defp scope_status(query, status) when status in [:open, :resolved, :archived],
    do: where(query, [c], c.status == ^status)

  defp scope_status(query, _other), do: query

  @doc "Tolerant lookup of a single message by id. Returns %Cairnloop.Message{} or nil. Used by ChatLive's role-dedup branch (Phase 28 Pitfall 7) so a stale broadcast id can never crash a customer's chat tab."
  def get_message(id) do
    repo().get(Cairnloop.Message, id)
  end

  def get_conversation!(id) do
    Conversation
    |> repo().get!(id)
    |> repo().preload(
      messages: from(m in Message, order_by: [asc: m.inserted_at]),
      drafts: from(d in Cairnloop.Automation.Draft, order_by: [asc: d.inserted_at])
    )
  end

  # Phase 28 D-05: create a bare conversation for an inbound widget customer.
  # Does NOT go through reply_to_conversation/4 — this is a simple single-row insert.
  # On success broadcasts {:conversations_changed} on "conversations" so InboxLive refreshes.
  # Returns {:ok, conversation} on success, {:error, changeset} on failure.
  def create_customer_conversation(attrs) when is_map(attrs) do
    changeset =
      Cairnloop.Conversation.changeset(%Cairnloop.Conversation{}, %{
        status: :open,
        subject: Map.get(attrs, :subject, "Customer chat"),
        host_user_id: Map.fetch!(attrs, :host_user_id)
      })

    case repo().insert(changeset) do
      {:ok, conversation} ->
        broadcast_safely("conversations", {:conversations_changed})
        {:ok, conversation}

      {:error, _} = error ->
        error
    end
  end

  # Phase 28 D-06: ingest a raw customer widget message as a :user-role Message.
  # Does NOT call reply_to_conversation/4 — that path triggers DraftWorker for :user
  # and is wrong for raw customer ingress (the widget message itself is the customer input;
  # DraftWorker would draft a reply to it, which is a separate concern handled by Plan 02+).
  # On success broadcasts TWO messages:
  #   1. {:message_created, message.id} on "conversation:#{conversation_id}" (D-17 trigger)
  #   2. {:conversations_changed} on "conversations" (D-09 InboxLive trigger)
  # Returns {:ok, message} on success, {:error, changeset} on failure.
  def ingest_widget_message(conversation_id, content) when is_binary(content) do
    changeset =
      Cairnloop.Message.changeset(%Cairnloop.Message{}, %{
        conversation_id: conversation_id,
        content: content,
        role: :user
      })

    case repo().insert(changeset) do
      {:ok, message} ->
        broadcast_safely("conversation:#{conversation_id}", {:message_created, message.id})
        broadcast_safely("conversations", {:conversations_changed})
        {:ok, message}

      {:error, _} = error ->
        error
    end
  end

  def reply_to_conversation(conversation_id, content, role \\ :agent, opts \\ []) do
    conversation = repo().get!(Conversation, conversation_id)
    actor = Keyword.get(opts, :actor)

    auditor =
      Keyword.get(
        opts,
        :auditor,
        Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
      )

    meta = %{conversation_id: conversation.id, role: role}

    Cairnloop.Telemetry.span([:conversation, :reply], meta, fn ->
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(
          :message,
          Message.changeset(%Message{}, %{
            conversation_id: conversation.id,
            content: content,
            role: role
          })
        )
        |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :open}))
        |> auditor.audit(:reply_to_conversation, actor, %{conversation_id: conversation.id})

      multi =
        if role == :user do
          multi
          |> Ecto.Multi.insert(
            :draft_job,
            Cairnloop.Automation.Workers.DraftWorker.new(
              %{"conversation_id" => conversation.id},
              schedule_in: 5
            )
          )
          |> Ecto.Multi.merge(fn _changes ->
            active_sla =
              repo().one(
                from(s in SLA,
                  where: s.conversation_id == ^conversation.id and s.status == :active
                )
              )

            if active_sla do
              Ecto.Multi.new()
            else
              target_at = DateTime.utc_now() |> DateTime.add(2, :hour)

              sla_changeset =
                SLA.changeset(%SLA{}, %{
                  conversation_id: conversation.id,
                  target_type: :first_response,
                  status: :active,
                  target_at: target_at
                })

              Ecto.Multi.new()
              |> Ecto.Multi.insert(:new_sla, sla_changeset)
              |> Ecto.Multi.merge(fn %{new_sla: sla} ->
                job =
                  Cairnloop.Workers.SlaCountdownWorker.new(%{"sla_id" => sla.id},
                    scheduled_at: target_at
                  )

                Ecto.Multi.insert(Ecto.Multi.new(), :sla_job, job)
              end)
            end
          end)
        else
          multi
          |> Ecto.Multi.merge(fn _changes ->
            active_sla =
              repo().one(
                from(s in SLA,
                  where: s.conversation_id == ^conversation.id and s.status == :active
                )
              )

            m = Ecto.Multi.new()

            m =
              if active_sla do
                Ecto.Multi.update(
                  m,
                  :fulfill_sla,
                  Ecto.Changeset.change(active_sla, %{
                    status: :fulfilled,
                    completed_at: DateTime.utc_now()
                  })
                )
              else
                m
              end

            target_at = DateTime.utc_now() |> DateTime.add(24, :hour)

            sla_changeset =
              SLA.changeset(%SLA{}, %{
                conversation_id: conversation.id,
                target_type: :resolution,
                status: :active,
                target_at: target_at
              })

            m
            |> Ecto.Multi.insert(:new_sla, sla_changeset)
            |> Ecto.Multi.merge(fn %{new_sla: sla} ->
              job =
                Cairnloop.Workers.SlaCountdownWorker.new(%{"sla_id" => sla.id},
                  scheduled_at: target_at
                )

              Ecto.Multi.insert(Ecto.Multi.new(), :sla_job, job)
            end)
          end)
        end

      result = repo().transaction(multi)

      # Phase 28 OQ-1 (additive, sealed contract preserved): post-commit broadcast so
      # the customer's ChatLive can render operator replies in real time (D-17).
      # Rationale: the insert has already committed — a missing PubSub registry must NOT
      # roll back committed data. Defensive try/rescue via broadcast_safely/2 (see Pitfall 3).
      # CRITICAL trailing-expression invariant: this case-statement is a SIDE-EFFECTING
      # STATEMENT only — its return value is intentionally ignored. {result, meta} MUST
      # remain the trailing expression of this Telemetry.span lambda so the span callback
      # receives the correct {result, meta} tuple. If you move the case below {result, meta}
      # the lambda returns :ok (from broadcast_safely/2) and silently corrupts the caller's
      # return value (locked by OQ-1 Test 3 in chat_test.exs).
      case result do
        {:ok, %{message: %{id: msg_id}}} ->
          broadcast_safely("conversation:#{conversation.id}", {:message_created, msg_id})

        _ ->
          :ok
      end

      {result, meta}
    end)
  end

  def resolve_conversation(conversation_id, opts) when is_list(opts) do
    {actor, metadata} = Keyword.pop!(opts, :resolved_by)

    auditor =
      Keyword.get(
        opts,
        :auditor,
        Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
      )

    conversation = repo().get!(Conversation, conversation_id)
    resolved_at = DateTime.utc_now()

    # Safely handle missing inserted_at for old rows or test mock edge cases.
    # timestamps() defaults to NaiveDateTime; coerce to UTC DateTime so DateTime.diff/3
    # receives two DateTime structs (its 4th clause requires both have utc_offset).
    raw_inserted_at = conversation.inserted_at || resolved_at

    inserted_at =
      case raw_inserted_at do
        %DateTime{} = dt -> dt
        %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
      end

    duration_seconds = DateTime.diff(resolved_at, inserted_at, :second)

    meta = %{
      conversation_id: conversation.id,
      host_user_id: conversation.host_user_id,
      actor: actor,
      metadata: Enum.into(metadata, %{})
    }

    Cairnloop.Telemetry.span([:conversation, :resolve], meta, fn ->
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :conversation,
        Ecto.Changeset.change(conversation, %{status: :resolved, resolved_at: resolved_at})
      )
      |> Ecto.Multi.insert(
        :system_message,
        Message.changeset(%Message{}, %{
          conversation_id: conversation.id,
          content: "Please rate your experience.",
          role: :system,
          metadata: %{"type" => "csat_request"}
        })
      )
      |> Ecto.Multi.insert(
        :notify_job,
        Cairnloop.Workers.NotifyResolvedWorker.new(%{
          "conversation_id" => conversation.id,
          "metadata" => Enum.into(metadata, %{})
        })
      )
      |> Ecto.Multi.insert(
        :resolved_case_index_job,
        Cairnloop.Retrieval.Workers.IndexResolvedConversation.new(%{
          "conversation_id" => conversation.id,
          "metadata" => Enum.into(metadata, %{})
        })
      )
      |> auditor.audit(:resolve_conversation, actor, %{conversation_id: conversation.id})
      |> Ecto.Multi.merge(fn _changes ->
        active_sla =
          repo().one(
            from(s in SLA, where: s.conversation_id == ^conversation.id and s.status == :active)
          )

        if active_sla do
          Ecto.Multi.update(
            Ecto.Multi.new(),
            :fulfill_sla,
            Ecto.Changeset.change(active_sla, %{status: :fulfilled, completed_at: resolved_at})
          )
        else
          Ecto.Multi.new()
        end
      end)
      |> repo().transaction()
      |> case do
        {:ok, results} ->
          measurements = %{duration_seconds: duration_seconds, count: 1}
          event_meta = Map.put(meta, :conversation, results.conversation)
          Cairnloop.Telemetry.execute([:conversation, :resolved], measurements, event_meta)

          {{:ok, results}, meta}

        error ->
          {error, meta}
      end
    end)
  end

  def submit_csat(conversation_id, rating) do
    conversation = repo().get!(Conversation, conversation_id)
    meta = %{conversation_id: conversation.id, rating: rating}

    Cairnloop.Telemetry.span([:feedback, :csat], meta, fn ->
      case conversation
           |> Ecto.Changeset.cast(%{"csat_rating" => rating}, [:csat_rating])
           |> repo().update() do
        {:ok, updated_conversation} ->
          {{:ok, updated_conversation}, meta}

        error ->
          {error, meta}
      end
    end)
  end

  # Phase 42 Plan 02 (THREAD-01, D-04/D-06/D-07): next open conversation in inbox order.
  # Additive sibling to list_conversations/1 — sealed clauses above are NOT modified.
  # select(:id) only — never a full row load (D-07, cheap read).
  # order_by mirrors inbox order: desc updated_at, then desc id as deterministic tiebreak (D-07).
  # Returns the next open conversation id, or nil when the queue is clear (D-06).
  def next_open_conversation(current_id) do
    Conversation
    |> where([c], c.status == :open and c.id != ^current_id)
    |> order_by([c], desc: c.updated_at, desc: c.id)
    |> limit(1)
    |> select([c], c.id)
    |> repo().one()
  end

  # Phase 28: defensive PubSub broadcast helper.
  # Wraps Phoenix.PubSub.broadcast/3 in try/rescue so a missing registry (dev, test,
  # headless test environments) can never propagate an error back into an already-committed
  # :ok branch. Pattern mirrors tool_execution_worker.ex:580-588 (defensive variant).
  defp broadcast_safely(topic, message) do
    try do
      Phoenix.PubSub.broadcast(Cairnloop.PubSub, topic, message)
    rescue
      _ -> :ok
    end
  end
end
