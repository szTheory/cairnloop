defmodule Cairnloop.Web.AuditLogPresenter do
  @moduledoc """
  Pure, total presenter for operator audit-log events (AUDIT-01).

  Mirrors `ToolProposalPresenter`/`ReviewTaskPresenter`:
  - Total functions with safe fallbacks — never crashes on unexpected input.
  - Returns strings and atoms only — never markup, never raw Elixir terms.

  Operates on the plain-map event shape the `Cairnloop.Auditor` behaviour returns
  (`%{inserted_at:, actor_id:, action:, reason:, metadata:}`), so it works uniformly
  for the governance-backed default auditor and any host-supplied auditor.

  Brand: action atoms are humanized (never `inspect/1` to operators); the raw map is
  only ever shown behind an explicit expander in the LiveView, never inline.
  """

  # ---------------------------------------------------------------------------
  # Action label — humanize governance event types + graceful fallback
  # ---------------------------------------------------------------------------

  @doc "Human label for an audit action/event_type (atom or string)."
  def action_label(:proposal_created), do: "Action proposed"
  def action_label(:proposal_blocked), do: "Action blocked"
  def action_label(:approval_requested), do: "Approval requested"
  def action_label(:approved), do: "Approved"
  def action_label(:rejected), do: "Rejected"
  def action_label(:deferred), do: "Deferred"
  def action_label(:expired), do: "Expired"
  def action_label(:invalidated), do: "Invalidated"
  def action_label(:resume_scheduled), do: "Resume scheduled"
  def action_label(:revalidation_passed), do: "Re-validation passed"
  def action_label(:revalidation_failed), do: "Re-validation failed"
  def action_label(:execution_started), do: "Execution started"
  def action_label(:execution_succeeded), do: "Executed"
  def action_label(:execution_attempt_failed), do: "Execution attempt failed"
  def action_label(:execution_failed), do: "Execution failed"
  def action_label(nil), do: "Unknown action"

  def action_label(value) when is_atom(value), do: humanize_token(Atom.to_string(value))

  def action_label(value) when is_binary(value) do
    case value do
      "" -> "Unknown action"
      _ -> humanize_token(value)
    end
  end

  def action_label(_), do: "Unknown action"

  # ---------------------------------------------------------------------------
  # Actor / timestamp
  # ---------------------------------------------------------------------------

  @doc "Human label for the actor; system/automated actions read as \"System\"."
  def actor_label(nil), do: "System"
  def actor_label(""), do: "System"
  def actor_label(actor) when is_binary(actor), do: actor
  def actor_label(actor) when is_atom(actor), do: Atom.to_string(actor)
  def actor_label(_), do: "System"

  @doc "Calm UTC timestamp label; nil/unknown renders as an em dash."
  def timestamp_label(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  def timestamp_label(%NaiveDateTime{} = dt) do
    dt
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  def timestamp_label(_), do: "—"

  @doc "Optional reason text; nil/blank renders as an em dash."
  def reason_label(reason) when is_binary(reason) and reason != "", do: reason
  def reason_label(_), do: "—"

  # ---------------------------------------------------------------------------
  # Metadata — humanized scalar rows (raw map stays behind the LiveView expander)
  # ---------------------------------------------------------------------------

  @doc """
  Humanized `{label, value}` rows for an event's metadata map.

  Scalar values are stringified; nested/structured values are summarized as
  \"(structured value)\" — the full raw map is only shown behind the explicit
  expander in the LiveView, never inline (brand §5.6).
  """
  def metadata_rows(metadata) when is_map(metadata) and map_size(metadata) > 0 do
    metadata
    |> Enum.map(fn {key, value} -> {humanize_token(to_string(key)), scalar_label(value)} end)
    |> Enum.sort_by(fn {label, _} -> label end)
  end

  def metadata_rows(_), do: []

  @doc "True when there is metadata worth showing in the raw expander."
  def has_metadata?(metadata) when is_map(metadata), do: map_size(metadata) > 0
  def has_metadata?(_), do: false

  # ---------------------------------------------------------------------------
  # Search predicate — case-insensitive over humanized + raw-ish fields
  # ---------------------------------------------------------------------------

  @doc """
  True when `event` matches the free-text `query` (case-insensitive). A blank query
  matches everything. Searches the action label, actor, reason, and metadata values.
  """
  def matches?(_event, query) when query in [nil, ""], do: true

  def matches?(event, query) when is_map(event) and is_binary(query) do
    needle = String.downcase(String.trim(query))

    haystack =
      [
        action_label(Map.get(event, :action)),
        actor_label(Map.get(event, :actor_id)),
        reason_label(Map.get(event, :reason)),
        metadata_haystack(Map.get(event, :metadata))
      ]
      |> Enum.join(" ")
      |> String.downcase()

    needle == "" or String.contains?(haystack, needle)
  end

  def matches?(_event, _query), do: true

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp metadata_haystack(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> "#{to_string(k)} #{scalar_label(v)}" end)
    |> Enum.join(" ")
  end

  defp metadata_haystack(_), do: ""

  defp scalar_label(value) when is_binary(value), do: value
  defp scalar_label(value) when is_integer(value), do: Integer.to_string(value)
  defp scalar_label(value) when is_float(value), do: Float.to_string(value)
  defp scalar_label(value) when is_boolean(value), do: if(value, do: "Yes", else: "No")
  defp scalar_label(nil), do: "—"
  defp scalar_label(value) when is_atom(value), do: humanize_token(Atom.to_string(value))
  defp scalar_label(_), do: "(structured value)"

  # "execution_succeeded" -> "Execution succeeded"; "Refund.Issue" -> "Refund.issue"
  defp humanize_token(token) when is_binary(token) do
    token
    |> String.replace(["_", "-"], " ")
    |> String.trim()
    |> case do
      "" -> "Unknown action"
      cleaned -> String.capitalize(cleaned)
    end
  end
end
