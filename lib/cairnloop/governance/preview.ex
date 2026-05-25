defmodule Cairnloop.Governance.Preview do
  @moduledoc """
  Total `render/1` function for governed tool proposals — hides the live-vs-fallback
  branching behind a single public API.

  ## Return values

  - `{:preview, String.t()}` — the tool's `preview/1` callback returned a non-empty
    binary string. The string is best-effort LIVE prose (labelled "current description"
    in the UI); it MAY diverge from the prose that was current at propose-time.
  - `{:structured, map()}` — the COMMON Phase-14 path. Built ENTIRELY from the
    propose-time snapshot. No live registry read for the structured fields (trust
    correctness). Used when no tool implements `preview/1`, when the tool is
    unregistered, when `preview/1` raises, or when it returns a non-binary.

  ## D-19 guard stack (live leg)

  1. `Cairnloop.ToolRegistry.find_tool_module/1` — unknown tool → structured fallback
  2. `Code.ensure_loaded?/1` — module not loaded → structured fallback
  3. `function_exported?(mod, :preview, 1)` — callback absent → structured fallback
  4. Atom rehydration of JSONB string keys via `String.to_existing_atom/1` + rescue
     ArgumentError — NEVER `String.to_atom/1` (unbounded-atom DoS / VM kill — T-14-01)
  5. `struct/2` rehydration — never re-running the tool's cast/validate pipeline (avoids validation side-effects)
  6. `try/rescue` around `mod.preview(input_struct)` — bad host tool degrades ONE card,
     never crashes the LiveView

  ## D-17 common path

  No tool in Phase 14 implements `preview/1`, so `{:structured, _}` is the expected
  result for all proposals in this phase.

  ## Phase 15 forward-compat guardrail — DISCHARGED

  The D-16 4-step mandate has been completed in Phase 15 (Plan 15-01):

  1. ✓ Nullable `rendered_consequence` and `title` columns added to `cairnloop_tool_proposals`
     (migration `20260524120100_add_snapshot_cols_to_proposals.exs`).
  2. ✓ Both columns populated in `Cairnloop.Governance.propose/3` from Phase 15 forward
     (`Preview.render/1` called at propose-time and result snapshotted — D15-14).
  3. ✓ Approval and execution surfaces MUST read the snapshotted `rendered_consequence` and
     `title` columns — NEVER call live `Preview.render/1` from an approval or execution surface
     (D-16). The live leg is for the timeline preview only; approval trust facts must be immutable.
  4. ✓ Test added asserting that the approval card shows the snapshotted consequence when it
     diverges from the live registry description (regression gate — `preview_test.exs` D15-14 block).

  Failure to snapshot at propose-time means approval surfaces will silently show different
  prose after a tool implementation changes — a trust and audit correctness failure. This guard
  remains here as the discoverable marker for future phases.
  """

  alias Cairnloop.Governance.ToolProposal
  alias Cairnloop.Web.ToolProposalPresenter

  @doc """
  Total render function for a governed tool proposal.

  Returns `{:preview, String.t()}` if the live `preview/1` leg succeeds,
  or `{:structured, map()}` as the COMMON fallback (D-17).

  The structured result is built from the propose-time snapshot only — no live
  config re-read for trust fields. The title fallback chain uses the live
  `__tool_spec__/0` Spec title only if the module is loaded (best-effort).
  """
  def render(%ToolProposal{} = proposal) do
    case try_live_preview(proposal) do
      {:preview, _} = result -> result
      :fallback -> {:structured, build_structured(proposal)}
    end
  end

  # ---------------------------------------------------------------------------
  # Live leg (D-19 guard stack)
  # ---------------------------------------------------------------------------

  defp try_live_preview(%ToolProposal{tool_ref: tool_ref, input_snapshot: input_snapshot}) do
    with {:ok, mod} <- Cairnloop.ToolRegistry.find_tool_module(tool_ref),
         true <- Code.ensure_loaded?(mod),
         true <- function_exported?(mod, :preview, 1),
         {:ok, input_struct} <- rehydrate_input(mod, input_snapshot),
         {:ok, result} <- call_preview(mod, input_struct) do
      {:preview, result}
    else
      _ -> :fallback
    end
  end

  # Rehydrate `input_snapshot` (potentially string-keyed after JSONB round-trip) into a
  # tool struct using `struct/2` — NOT the tool's cast/validate pipeline (no validation side-effects).
  # Atomizes string keys via `String.to_existing_atom/1` + rescue ArgumentError.
  # NEVER `String.to_atom/1` — unbounded-atom DoS (T-14-01, D-19).
  defp rehydrate_input(mod, snapshot) when is_map(snapshot) do
    atomized =
      Enum.into(snapshot, %{}, fn
        {key, value} when is_binary(key) ->
          # D-19 footgun 1: JSONB round-trip produces string keys
          atom_key =
            try do
              String.to_existing_atom(key)
            rescue
              ArgumentError -> key
            end

          {atom_key, value}

        pair ->
          pair
      end)

    {:ok, struct(mod, atomized)}
  rescue
    _ -> :error
  end

  defp rehydrate_input(_mod, _snapshot), do: :error

  # Guard the call to preview/1: require a non-empty binary result — D-19
  defp call_preview(mod, input_struct) do
    try do
      case mod.preview(input_struct) do
        result when is_binary(result) and result != "" -> {:ok, result}
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end

  # ---------------------------------------------------------------------------
  # Structured fallback (common Phase-14 path — D-17)
  # ---------------------------------------------------------------------------

  # Built ENTIRELY from the propose-time snapshot — no live config re-read for
  # trust fields. Title uses a best-effort live Spec fallback if the module is loaded.
  defp build_structured(%ToolProposal{} = proposal) do
    %{
      title: resolve_title(proposal),
      input_rows: ToolProposalPresenter.input_rows(proposal.input_snapshot),
      risk_tier: proposal.risk_tier,
      risk_tier_label: ToolProposalPresenter.risk_tier_label(proposal.risk_tier),
      approval_mode: proposal.approval_mode,
      approval_mode_label: ToolProposalPresenter.approval_mode_label(proposal.approval_mode),
      scope_summary: ToolProposalPresenter.scope_summary(proposal.scope_snapshot),
      status: proposal.status
    }
  end

  # Title fallback chain (D-18):
  # 1. Live Spec.title if module loaded (best-effort, may differ from propose-time)
  # 2. Last segment of tool_ref, humanized (e.g. "Cairnloop.Tools.LookupOrder" → "Lookup Order")
  # 3. "Unknown tool" sentinel — never a raw module atom string
  defp resolve_title(%ToolProposal{tool_ref: tool_ref}) do
    with {:ok, mod} <- Cairnloop.ToolRegistry.find_tool_module(tool_ref),
         true <- Code.ensure_loaded?(mod),
         spec <- mod.__tool_spec__(),
         title when is_binary(title) and title != "" <- spec.title do
      title
    else
      _ -> humanize_tool_ref(tool_ref)
    end
  end

  # Extract and humanize the last module segment — never returns the raw "Elixir.X.Y" string
  defp humanize_tool_ref(nil), do: "Unknown tool"

  defp humanize_tool_ref(tool_ref) when is_binary(tool_ref) do
    tool_ref
    |> String.split(".")
    |> List.last()
    |> humanize_label()
  end

  defp humanize_label(nil), do: "Unknown tool"
  # WR-06: guard empty string so a trailing-dot tool_ref never yields a blank headline
  defp humanize_label(""), do: "Unknown tool"

  defp humanize_label(label) do
    label
    |> String.replace(~r/(?<=[a-z])(?=[A-Z])/, " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
