defmodule Cairnloop.Chat do
  import Ecto.Query
  alias Cairnloop.{Conversation, Message}

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

  def reply_to_conversation(conversation_id, content, role \\ :agent) do
    conversation = repo().get!(Conversation, conversation_id)
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

      multi =
        if role == :user do
          Ecto.Multi.insert(
            multi,
            :draft_job,
            Cairnloop.Automation.Workers.DraftWorker.new(
              %{"conversation_id" => conversation.id},
              schedule_in: 5
            )
          )
        else
          multi
        end

      result = repo().transaction(multi)
      {result, meta}
    end)
  end

  def resolve_conversation(conversation_id, opts) when is_list(opts) do
    {actor, metadata} = Keyword.pop!(opts, :resolved_by)
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
      |> repo().transaction()
      |> case do
        {:ok, results} ->
          updated_conversation = results.conversation
          notify_resolved(updated_conversation, opts)

          extended_meta = Map.put(meta, :business_duration_seconds, duration_seconds)
          :telemetry.execute([:cairnloop, :conversation, :resolved], %{}, extended_meta)

          {{:ok, results}, extended_meta}

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

  defp notify_resolved(conversation, metadata) do
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_conversation_resolved(conversation, metadata)

      _ ->
        :ok
    end
  end
end