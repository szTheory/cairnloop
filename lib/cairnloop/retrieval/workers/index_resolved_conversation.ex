defmodule Cairnloop.Retrieval.Workers.IndexResolvedConversation do
  use Oban.Worker, queue: :default, unique: [period: 60]

  import Ecto.Query

  alias Cairnloop.Conversation
  alias Cairnloop.Embedder.ExternalApi
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeBase.MarkdownParser
  alias Cairnloop.Retrieval.{ResolvedCaseChunk, ResolvedCaseEvidence}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id} = args}) do
    case repo().get(Conversation, conversation_id) do
      nil ->
        {:error, :conversation_not_found}

      conversation ->
        conversation = repo().preload(conversation, :messages)
        metadata = normalize_metadata(Map.get(args, "metadata", %{}))
        citation_backreferences = build_citation_backreferences(conversation.messages)
        evidence_attrs = build_evidence_attrs(conversation, metadata, citation_backreferences)
        chunk_sections = build_chunk_sections(evidence_attrs)

        case ExternalApi.generate_embeddings(Enum.map(chunk_sections, & &1.content)) do
          {:ok, embeddings} ->
            persist_evidence(conversation, evidence_attrs, chunk_sections, embeddings)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp persist_evidence(conversation, evidence_attrs, chunk_sections, embeddings) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    repo().transaction(fn ->
      evidence =
        repo().one(from e in ResolvedCaseEvidence, where: e.conversation_id == ^conversation.id)

      evidence_changeset =
        (evidence || %ResolvedCaseEvidence{})
        |> ResolvedCaseEvidence.changeset(evidence_attrs)

      with {:ok, evidence_record} <- repo().insert_or_update(evidence_changeset) do
        chunk_records =
          Enum.zip(chunk_sections, embeddings)
          |> Enum.map(fn {section, embedding} ->
            %{
              resolved_case_evidence_id: evidence_record.id,
              chunk_index: section.chunk_index,
              content: section.content,
              embedding: Pgvector.new(embedding),
              inserted_at: now,
              updated_at: now
            }
          end)

        Ecto.Multi.new()
        |> Ecto.Multi.delete_all(
          :delete_old_chunks,
          from(c in ResolvedCaseChunk, where: c.resolved_case_evidence_id == ^evidence_record.id)
        )
        |> Ecto.Multi.insert_all(:insert_chunks, ResolvedCaseChunk, chunk_records)
        |> repo().transaction()

        :ok
      else
        {:error, changeset} -> repo().rollback(changeset)
      end
    end)
    |> case do
      {:ok, :ok} ->
        _ = schedule_gap_candidate_refresh(conversation.id)
        :ok

      {:ok, {:ok, _}} ->
        _ = schedule_gap_candidate_refresh(conversation.id)
        :ok

      {:error, reason} -> {:error, reason}
    end
  end

  defp schedule_gap_candidate_refresh(conversation_id) do
    KnowledgeAutomation.schedule_gap_candidate_refresh(%{
      "source_type" => "manual_handling_case",
      "conversation_id" => conversation_id
    })
  rescue
    _ -> :ok
  end

  defp build_evidence_attrs(conversation, metadata, citation_backreferences) do
    user_messages = filter_messages(conversation.messages, :user)
    agent_messages = filter_messages(conversation.messages, :agent)

    %{
      conversation_id: conversation.id,
      subject: conversation.subject || "Conversation ##{conversation.id}",
      issue_summary: summarize_issue(user_messages, conversation.subject),
      resolution_note: summarize_resolution(agent_messages),
      actions_taken: summarize_actions(agent_messages),
      outcome: "resolved",
      resolved_at: conversation.resolved_at || DateTime.utc_now(),
      host_user_id: to_string(conversation.host_user_id || ""),
      metadata: metadata,
      citation_backreferences: citation_backreferences
    }
  end

  defp build_chunk_sections(evidence_attrs) do
    document = [
      "# #{evidence_attrs.subject}",
      "## Issue Summary\n#{evidence_attrs.issue_summary}",
      "## Resolution Note\n#{evidence_attrs.resolution_note}",
      "## Actions Taken\n#{Enum.join(evidence_attrs.actions_taken, "\n")}",
      "## Outcome\n#{evidence_attrs.outcome}"
    ]
    |> Enum.join("\n\n")

    MarkdownParser.parse_sections(document)
  end

  defp filter_messages(messages, role) do
    Enum.filter(messages || [], &(&1.role == role))
  end

  defp summarize_issue([], subject), do: subject || "Resolved support issue"
  defp summarize_issue([message | _], _subject), do: String.trim(message.content)

  defp summarize_resolution([]), do: "Conversation resolved by host agent."
  defp summarize_resolution(messages), do: messages |> List.last() |> Map.fetch!(:content) |> String.trim()

  defp summarize_actions(messages) do
    messages
    |> Enum.map(&String.trim(&1.content))
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(-3)
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.take(10)
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_metadata(_), do: %{}

  defp build_citation_backreferences(messages) do
    Enum.map(messages || [], fn message ->
      %{
        "message_id" => message.id,
        "role" => message.role,
        "inserted_at" => message.inserted_at
      }
    end)
  end
end
