defmodule Cairnloop.Web.ToolProposalPresenter do
  @moduledoc """
  Pure, total presenter for `Cairnloop.Governance.ToolProposal` structs.

  Mirrors `ReviewTaskPresenter` and `GapCandidatePresenter` exactly:
  - Total functions with safe fallbacks — no crashes on unexpected input
  - Pattern-match on struct and bare atoms
  - Returns strings and atoms only — never markup, never raw Elixir terms
  - Never re-reads live config at render time (snapshots are truth for trust fields)

  D-22 masking choke point: `input_rows/1` is the ONLY place raw `input_snapshot`
  values are converted to display rows; it allowlists known scalar fields and
  applies the "Unsupported value" posture to nested/unknown/sensitive values.

  D-14: `reason_label/1` humanizes all reason shapes (including `{:missing_scopes, _}`
  tuples and atoms) — never passes `inspect/1` output to operators.

  D-13 / brand §7.5: `risk_tier_tone/1` returns an atom (:info/:warning/:danger)
  that LiveView maps to color — always paired with text, never state-by-color-alone.
  """

  alias Cairnloop.Governance.{ToolActionEvent, ToolProposal}

  # ---------------------------------------------------------------------------
  # Status display — D-11 locked copy
  # ---------------------------------------------------------------------------

  @doc "Human label for a proposal status atom or ToolProposal struct."
  def status_label(%ToolProposal{status: status}), do: status_label(status)
  def status_label(:proposed), do: "Proposed"
  def status_label(:needs_input), do: "Needs input"
  def status_label(:scope_invalid), do: "Not available here"
  def status_label(:policy_denied), do: "Blocked by policy"
  def status_label(_), do: "Unknown status"

  @doc "Status meaning — one calm sentence explaining what this state means for operators."
  def status_meaning(:proposed), do: "This action is awaiting operator review before it can run."

  def status_meaning(:needs_input),
    do: "The action is missing required input and cannot proceed yet."

  def status_meaning(:scope_invalid),
    do:
      "This tool is not available in the current context or the actor lacks the required permissions."

  def status_meaning(:policy_denied),
    do: "A policy gate prevented this action from running in this context."

  def status_meaning(_), do: "Status details are not available."

  # ---------------------------------------------------------------------------
  # Status grouping — D-10 four groups
  # ---------------------------------------------------------------------------

  @doc """
  Groups proposal status into display buckets.

  - :awaiting — :proposed, :needs_input (action needed but not yet blocked)
  - :blocked  — :scope_invalid, :policy_denied (terminal blocked state in Phase 14)
  - :active   — declared for future Phase 15/16 running/approved states (unreachable now)
  - :done     — declared for future completed/executed states (unreachable now)
  """
  def status_group(:proposed), do: :awaiting
  def status_group(:needs_input), do: :awaiting
  def status_group(:scope_invalid), do: :blocked
  def status_group(:policy_denied), do: :blocked
  # ToolApproval status atoms — D15-16 zero relabeling (above catch-all).
  # These map the separate approval axis into the same four display groups, so the
  # mapping is correct wherever an approval status is grouped (15-04-a).
  def status_group(:pending), do: :awaiting
  def status_group(:approved), do: :active
  def status_group(:execution_pending), do: :active
  def status_group(:rejected), do: :done
  def status_group(:deferred), do: :done
  def status_group(:expired), do: :done
  def status_group(:invalidated), do: :done
  # Phase 16 execution terminal statuses — MUST precede catch-all (Pitfall 6, D16-11)
  def status_group(:executed), do: :done
  def status_group(:execution_failed), do: :done
  def status_group(_), do: :blocked

  @doc "Human label for the status group."
  def status_group_label(:awaiting), do: "Awaiting"
  def status_group_label(:blocked), do: "Blocked"
  def status_group_label(:active), do: "Active"
  def status_group_label(:done), do: "Done"
  def status_group_label(_), do: "Unknown"

  # ---------------------------------------------------------------------------
  # Risk tier — D-13
  # ---------------------------------------------------------------------------

  @doc "Human label for a risk tier atom."
  def risk_tier_label(:read_only), do: "Read-only"
  def risk_tier_label(:low_write), do: "Low write"
  def risk_tier_label(:high_write), do: "High write"
  def risk_tier_label(:destructive), do: "Destructive"
  def risk_tier_label(_), do: "Unknown"

  @doc """
  Semantic tone for the risk tier — returns an atom only (brand §7.5 / D-13).
  LiveView MUST pair this with a text label — never rely on color alone.

  :info    — :read_only (low risk, informational)
  :warning — :low_write (moderate risk)
  :danger  — :high_write, :destructive (high risk)
  """
  def risk_tier_tone(:read_only), do: :info
  def risk_tier_tone(:low_write), do: :warning
  def risk_tier_tone(:high_write), do: :danger
  def risk_tier_tone(:destructive), do: :danger
  def risk_tier_tone(_), do: :info

  # ---------------------------------------------------------------------------
  # Approval mode — D-12 honesty seam
  # ---------------------------------------------------------------------------

  @doc "Human label for an approval mode atom."
  def approval_mode_label(:auto), do: "Auto"
  def approval_mode_label(:requires_approval), do: "Requires approval"
  def approval_mode_label(:always_block), do: "Always blocked"
  def approval_mode_label(_), do: "Unknown"

  @doc """
  Future-tense operator copy describing the approval gate — D-12 honesty seam.

  Returns:
  - `nil`    for :auto (no gate to describe)
  - `String` for :requires_approval (gate exists — future-tense)
  - `String` for :always_block (terminal — "cannot be approved or run")
  """
  def approval_outlook(:auto), do: nil
  def approval_outlook(:requires_approval), do: "Will require approval before it can run."
  def approval_outlook(:always_block), do: "This action cannot be approved or run."
  def approval_outlook(_), do: nil

  @doc """
  Present-tense operator copy for an active approval record (D15-16 real copy).

  Takes a `%ToolApproval{}` struct or a map with a `:status` key (and optionally `:reason`).
  Returns a calm, present-tense string for operators — or `nil` for unknown states.

  Replaces the future-tense `approval_outlook/1` honesty seam when an active approval exists.
  Never re-reads live config (brand §5.3/§5.6 reason-forward, no raw terms).
  """
  def approval_outlook_for_approval(%{status: :pending}),
    do: "Pending approval — an operator must approve, reject, or defer this action."

  def approval_outlook_for_approval(%{status: :approved}),
    do: "Approved — resuming with current policy check."

  def approval_outlook_for_approval(%{status: :execution_pending}),
    do: "Approved — ready to execute."

  def approval_outlook_for_approval(%{status: :rejected, reason: reason}),
    do: "Rejected: #{reason || "No reason provided."}"

  def approval_outlook_for_approval(%{status: :deferred, reason: reason}),
    do: "Deferred: #{reason || "No reason provided."}"

  def approval_outlook_for_approval(%{status: :expired}),
    do: "Approval request expired."

  def approval_outlook_for_approval(%{status: :invalidated}),
    do: "Approval invalidated — policy or scope changed since approval."

  # Phase 16 execution terminal clauses — MUST precede catch-all (D16-11, Pitfall 6)
  # Reads reason via dual-key lookup (atom then string) for JSONB survival (D16-11).
  # The worker stores the humanized result_summary in approval.reason via decision_changeset/6
  # (tool_execution_worker.ex record_success: decision_changeset(approval, :executed, "executed", result_summary, ...)).
  # Never surfaces raw Elixir terms — humanized strings only (T-16-10, brand §5.6).
  def approval_outlook_for_approval(%{status: :executed} = approval) do
    summary = Map.get(approval, :reason) || Map.get(approval, "reason")
    "Action completed: #{summary || "Done."}"
  end

  def approval_outlook_for_approval(%{status: :execution_failed} = approval) do
    reason = Map.get(approval, :reason) || Map.get(approval, "reason")
    "Action failed: #{reason || "An error occurred."}"
  end

  def approval_outlook_for_approval(_), do: nil

  # ---------------------------------------------------------------------------
  # Reason label — D-14 no inspect, no raw Elixir terms
  # ---------------------------------------------------------------------------

  @reason_labels %{
    denied: "Denied by policy",
    no_policy_defined: "No policy defined",
    scope_mismatch: "Scope mismatch",
    unknown_tool: "Tool not available"
  }

  @doc """
  Humanizes a reason value — never passes raw inspect output to operators (D-14).

  Handles:
  - nil → nil
  - `{:missing_scopes, scopes}` → "Missing scopes: scope1, scope2"
  - known atom → human-readable label from @reason_labels
  - unknown atom → humanize via capitalize-and-replace
  - string → pass through
  - any tuple → generic human fallback (no raw inspect)
  """
  def reason_label(nil), do: nil

  def reason_label({:missing_scopes, scopes}) when is_list(scopes) do
    scope_names = Enum.map(scopes, &humanize_atom/1)
    "Missing scopes: " <> Enum.join(scope_names, ", ")
  end

  def reason_label(reason) when is_atom(reason) do
    Map.get(@reason_labels, reason, humanize_atom(reason))
  end

  def reason_label(reason) when is_binary(reason), do: reason

  # Tuple and other complex types — humanize without inspect (D-14)
  def reason_label({reason, _detail}) when is_atom(reason) do
    Map.get(@reason_labels, reason, humanize_atom(reason))
  end

  def reason_label(_), do: "Action was blocked"

  # ---------------------------------------------------------------------------
  # Input rows — D-22 masking choke point
  # ---------------------------------------------------------------------------

  @doc """
  Converts an `input_snapshot` map to a list of `{label, value}` display rows.

  MASKING RULES (D-22):
  - Iterates ALL keys (both atom and string-keyed JSONB snapshots are supported)
  - Scalar values (string, number, boolean) are humanized and displayed
  - Lists of scalars are joined with ", "
  - Nested maps, tuples, and other complex values → "Unsupported value" sentinel
  - Sensitive field names (containing "password", "token", "secret", "key") → "••••••"
  - Never dumps raw nested structures to operators
  """
  def input_rows(snapshot) when is_map(snapshot) do
    snapshot
    |> Enum.map(fn {k, v} ->
      label = humanize_context_label(k)
      value = if sensitive_field?(k), do: "••••••", else: normalize_input_value(v)
      {label, value}
    end)
    |> Enum.sort_by(fn {label, _} -> label end)
  end

  def input_rows(_), do: []

  # ---------------------------------------------------------------------------
  # Scope summary
  # ---------------------------------------------------------------------------

  @doc "Human summary of required scopes from a scope_snapshot map."
  def scope_summary(%{scopes: []}), do: "No special scopes required."
  def scope_summary(%{"scopes" => []}), do: "No special scopes required."

  def scope_summary(%{scopes: scopes}) when is_list(scopes) do
    "Required scopes: " <> (Enum.map(scopes, &humanize_atom/1) |> Enum.join(", "))
  end

  def scope_summary(%{"scopes" => scopes}) when is_list(scopes) do
    "Required scopes: " <> (Enum.map(scopes, &humanize_atom/1) |> Enum.join(", "))
  end

  def scope_summary(_), do: "Scope details not available."

  # ---------------------------------------------------------------------------
  # Policy explanation — dual-key lookup for JSONB string-key survival
  # ---------------------------------------------------------------------------

  @doc """
  Returns a calm one-sentence explanation from the policy_snapshot.

  Uses dual-key lookup (atom + string) to survive the JSONB string-key
  round-trip (mirrors ReviewTaskPresenter.metadata_value/2). Raw map is NOT
  returned — only a humanized sentence. (D-14 / brand §5.6)
  """
  def policy_explanation(snapshot) when is_map(snapshot) do
    outcome = metadata_value(snapshot, :outcome)

    cond do
      # WR-06: outcome alone recognizes the denial — reason must not gate recognition.
      # A policy_denied proposal with an empty reason is still denied; showing
      # "Policy details are not available." was misleading. Reason is used only to
      # enrich the sentence, not to decide whether the denial is recognized.
      outcome in [:policy_denied, "policy_denied"] ->
        "This action was blocked by a policy gate."

      outcome in [:scope_invalid, "scope_invalid"] ->
        "This action is not available in the current scope."

      outcome in [:proposed, "proposed", nil] ->
        "This action passed all policy checks at submission time."

      true ->
        "Policy details are not available."
    end
  end

  def policy_explanation(_), do: "Policy details are not available."

  # ---------------------------------------------------------------------------
  # Block reason copy
  # ---------------------------------------------------------------------------

  @doc "Returns operator copy explaining why a proposal was blocked, or nil/empty for non-blocked."
  def block_reason_copy(%ToolProposal{status: :scope_invalid}) do
    "This tool is not available in the current context."
  end

  def block_reason_copy(%ToolProposal{status: :policy_denied}) do
    "A policy gate prevented this action from running."
  end

  def block_reason_copy(%ToolProposal{}), do: nil

  # ---------------------------------------------------------------------------
  # Event history line — D-24 catch-all forward-compat
  # ---------------------------------------------------------------------------

  @doc """
  Returns a human-readable line for a ToolActionEvent.

  Catch-all → "Workflow updated" for any unrecognized event_type (D-24).
  """
  def history_line(%ToolActionEvent{event_type: :proposal_created, actor_id: actor_id}) do
    "Proposal created by #{actor_id}"
  end

  def history_line(%ToolActionEvent{
        event_type: :proposal_blocked,
        to_status: status,
        actor_id: actor_id
      }) do
    status_copy = status_label(status)
    "Blocked (#{status_copy}) for #{actor_id}"
  end

  # Approval event type clauses — D15-16, D-24 (ABOVE the catch-all)
  def history_line(%ToolActionEvent{event_type: :approval_requested, actor_id: actor_id}) do
    "Approval requested by #{actor_id}"
  end

  def history_line(%ToolActionEvent{event_type: :approved, actor_id: actor_id}) do
    "Approved by #{actor_id}"
  end

  def history_line(%ToolActionEvent{event_type: :rejected, actor_id: actor_id, reason: reason}) do
    "Rejected by #{actor_id}: #{reason || "No reason provided."}"
  end

  def history_line(%ToolActionEvent{event_type: :deferred, actor_id: actor_id, reason: reason}) do
    "Deferred by #{actor_id}: #{reason || "No reason provided."}"
  end

  def history_line(%ToolActionEvent{event_type: :expired}) do
    "Approval request expired."
  end

  def history_line(%ToolActionEvent{event_type: :invalidated, reason: reason}) do
    "Approval invalidated: #{reason || "Policy or scope changed."}"
  end

  def history_line(%ToolActionEvent{event_type: :revalidation_passed}) do
    "Re-validation passed — execution pending."
  end

  def history_line(%ToolActionEvent{event_type: :revalidation_failed, reason: reason}) do
    "Re-validation failed: #{reason || "Policy or scope changed."}"
  end

  def history_line(%ToolActionEvent{event_type: :resume_scheduled}) do
    "Resume scheduled."
  end

  # Phase 16 execution event clauses — MUST precede catch-all (D16-11, D-24, Pitfall 6)
  # Reads attempt from STRING key "attempt" (JSONB round-trip: atom keys become strings after SELECT).
  # Never surfaces raw Elixir terms — humanized strings only (T-16-10, brand §5.6).
  def history_line(%ToolActionEvent{event_type: :execution_succeeded, metadata: meta}) do
    attempt = Map.get(meta || %{}, "attempt", 1)
    "Action completed (attempt #{attempt})."
  end

  def history_line(%ToolActionEvent{
        event_type: :execution_attempt_failed,
        reason: reason,
        metadata: meta
      }) do
    attempt = Map.get(meta || %{}, "attempt", 1)
    "Attempt #{attempt} failed: #{reason || "Transient error — will retry."}"
  end

  def history_line(%ToolActionEvent{event_type: :execution_failed, reason: reason}) do
    "Action failed permanently: #{reason || "All retry attempts exhausted."}"
  end

  # D-24 catch-all: unknown event types must not crash; future event types get a neutral label
  def history_line(%ToolActionEvent{}), do: "Workflow updated"

  # ---------------------------------------------------------------------------
  # Event timestamp label — mirrors SearchResultPresenter.relative_time/1
  # ---------------------------------------------------------------------------

  @doc "Human-readable relative timestamp for an event datetime."
  def event_timestamp_label(nil), do: "Unknown time"
  def event_timestamp_label(%DateTime{} = dt), do: relative_time(dt)

  def event_timestamp_label(%NaiveDateTime{} = dt),
    do: relative_time(DateTime.from_naive!(dt, "Etc/UTC"))

  def event_timestamp_label(_), do: "Unknown time"

  # ---------------------------------------------------------------------------
  # Trace metadata — de-emphasized mono data for operators
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of de-emphasized trace fields for a proposal.
  Safe for display; all values are strings. Shows a short idempotency key suffix.
  """
  def trace_metadata(%ToolProposal{} = proposal) do
    key_short =
      case proposal.idempotency_key do
        key when is_binary(key) and byte_size(key) > 8 -> "…" <> String.slice(key, -8, 8)
        key when is_binary(key) -> key
        _ -> "—"
      end

    tool_display =
      case proposal.tool_ref do
        ref when is_binary(ref) ->
          ref |> String.split(".") |> List.last() |> humanize_context_label()

        _ ->
          "Unknown"
      end

    %{
      proposal_id: to_string(proposal.id || "—"),
      tool_ref: tool_display,
      tool_version: proposal.tool_version || "—",
      idempotency_key: key_short
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Dual-key map lookup (atom + string): survives JSONB round-trips where atom keys
  # become strings after Postgres INSERT+SELECT. Mirrors ReviewTaskPresenter.metadata_value/2.
  # WR-05: use Map.fetch/2 so a stored `false` value is not discarded by ||.
  defp metadata_value(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp metadata_value(_, _), do: nil

  # Humanize atom: replace underscores, capitalize — mirrors GapCandidatePresenter.humanize_atom/1
  defp humanize_atom(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_atom(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_atom(_), do: "Unknown"

  # Humanize a context label (key) — mirrors ConversationLive.humanize_context_label/1
  defp humanize_context_label(label) do
    label
    |> to_string()
    |> String.replace("_", " ")
    # Split CamelCase boundaries so module-derived names humanize correctly
    # (e.g. "InternalNote" -> "Internal Note", not "Internalnote").
    |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1 \\2")
    |> String.split(" ", trim: true)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Normalize a scalar value for display — mirrors ConversationLive.normalize_context_value/1
  # Returns "Unsupported value" for nested/complex values (D-22 masking posture)
  defp normalize_input_value(value) when is_binary(value), do: value
  defp normalize_input_value(value) when is_number(value), do: to_string(value)
  defp normalize_input_value(value) when is_boolean(value), do: to_string(value)
  defp normalize_input_value(nil), do: ""

  defp normalize_input_value(value) when is_list(value) do
    if Enum.all?(value, fn v -> is_binary(v) or is_number(v) or is_boolean(v) end) do
      Enum.map(value, &normalize_input_value/1) |> Enum.join(", ")
    else
      "Unsupported value"
    end
  end

  defp normalize_input_value(_), do: "Unsupported value"

  # Detect sensitive field names that should be masked
  defp sensitive_field?(key) when is_atom(key), do: sensitive_field?(Atom.to_string(key))

  defp sensitive_field?(key) when is_binary(key) do
    lowered = String.downcase(key)
    String.contains?(lowered, ["password", "token", "secret", "key", "credential"])
  end

  defp sensitive_field?(_), do: false

  # Relative time — mirrors SearchResultPresenter.relative_time/1
  defp relative_time(%DateTime{} = datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)
    humanize_duration(max(seconds, 0))
  end

  defp humanize_duration(seconds) when seconds < 60, do: "just now"
  defp humanize_duration(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m ago"
  defp humanize_duration(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h ago"
  defp humanize_duration(seconds) when seconds < 2_592_000, do: "#{div(seconds, 86_400)}d ago"

  defp humanize_duration(seconds) when seconds < 31_536_000,
    do: "#{div(seconds, 2_592_000)}mo ago"

  defp humanize_duration(seconds), do: "#{div(seconds, 31_536_000)}y ago"
end
