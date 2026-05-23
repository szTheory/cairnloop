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

  def get_conversation!(id) do
    Conversation
    |> repo().get!(id)
    |> repo().preload(
      messages: from(m in Message, order_by: [asc: m.inserted_at]),
      drafts: from(d in Cairnloop.Automation.Draft, order_by: [asc: d.inserted_at])
    )
  end

  def reply_to_conversation(conversation_id, content, role \\ :agent, opts \\ []) do
    conversation = repo().get!(Conversation, conversation_id)
    actor = Keyword.get(opts, :actor)
    auditor = Keyword.get(opts, :auditor, Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp))
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
            active_sla = repo().one(from s in SLA, where: s.conversation_id == ^conversation.id and s.status == :active)
            if active_sla do
              Ecto.Multi.new()
            else
              target_at = DateTime.utc_now() |> DateTime.add(2, :hour)
              sla_changeset = SLA.changeset(%SLA{}, %{
                conversation_id: conversation.id,
                target_type: :first_response,
                status: :active,
                target_at: target_at
              })

              Ecto.Multi.new()
              |> Ecto.Multi.insert(:new_sla, sla_changeset)
              |> Ecto.Multi.merge(fn %{new_sla: sla} ->
                job = Cairnloop.Workers.SlaCountdownWorker.new(%{"sla_id" => sla.id}, scheduled_at: target_at)
                Ecto.Multi.insert(Ecto.Multi.new(), :sla_job, job)
              end)
            end
          end)
        else
          multi
          |> Ecto.Multi.merge(fn _changes ->
            active_sla = repo().one(from s in SLA, where: s.conversation_id == ^conversation.id and s.status == :active)
            
            m = Ecto.Multi.new()
            m = if active_sla do
              Ecto.Multi.update(m, :fulfill_sla, Ecto.Changeset.change(active_sla, %{status: :fulfilled, completed_at: DateTime.utc_now()}))
            else
              m
            end

            target_at = DateTime.utc_now() |> DateTime.add(24, :hour)
            sla_changeset = SLA.changeset(%SLA{}, %{
              conversation_id: conversation.id,
              target_type: :resolution,
              status: :active,
              target_at: target_at
            })

            m
            |> Ecto.Multi.insert(:new_sla, sla_changeset)
            |> Ecto.Multi.merge(fn %{new_sla: sla} ->
              job = Cairnloop.Workers.SlaCountdownWorker.new(%{"sla_id" => sla.id}, scheduled_at: target_at)
              Ecto.Multi.insert(Ecto.Multi.new(), :sla_job, job)
            end)
          end)
        end

      result = repo().transaction(multi)
      {result, meta}
    end)
  end

  def resolve_conversation(conversation_id, opts) when is_list(opts) do
    {actor, metadata} = Keyword.pop!(opts, :resolved_by)
    auditor = Keyword.get(opts, :auditor, Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp))
    conversation = repo().get!(Conversation, conversation_id)
    resolved_at = DateTime.utc_now()

    # Safely handle missing inserted_at for old rows or test mock edge cases
    inserted_at = conversation.inserted_at || resolved_at
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
        active_sla = repo().one(from s in SLA, where: s.conversation_id == ^conversation.id and s.status == :active)
        if active_sla do
          Ecto.Multi.update(Ecto.Multi.new(), :fulfill_sla, Ecto.Changeset.change(active_sla, %{status: :fulfilled, completed_at: resolved_at}))
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
end
