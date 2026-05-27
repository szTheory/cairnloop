defmodule Cairnloop.Outbound do
  @moduledoc """
  Facade for programmatically triggering support lifecycle events (outbound messages).

  ## Sealing posture (D-12)

  `trigger/2`'s **public signature** `trigger(conversation_id, opts)` is sealed at the
  Phase 22 / 23 / 24 contract. Phase 25 adds the additive optional key
  `:bulk_envelope_id` (default `nil`); Phase 24 callers that do not pass it continue
  to observe identical behavior.

  ## Bulk fan-out (Phase 25, D-13)

  `bulk_trigger/2` is the new envelope entry point that lets `InboxLive` (plan 03)
  fan out the same per-recipient `trigger/2` primitive across N conversations under
  a single durable `Cairnloop.Outbound.BulkEnvelope` row. Both `trigger/2` and
  `bulk_trigger/2` share a private `build_trigger_multi/2` helper that returns an
  `Ecto.Multi` WITHOUT running it — research Open Question 1 — so the bulk path
  composes per-recipient multis into one merged transaction without nesting.

  ## Cap (D-09)

  `bulk_trigger/2` enforces `length(conversation_ids) <= max_batch_size()` at the
  envelope boundary regardless of caller (defense-in-depth — research Pitfall 4).
  `max_batch_size/0` reads the `:cairnloop, :max_batch_size` application env (default
  `25`) — research Open Question 3.
  """
  alias Cairnloop.Message
  alias Cairnloop.Outbound.BulkEnvelope
  alias Cairnloop.Outbound.Telemetry.Traces

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  # D-09 / Pitfall 4: cap is read fresh on each call so ops can tune via env without
  # restart. Direct Application.get_env per research Open Question 3 (no Config module).
  defp max_batch_size, do: Application.get_env(:cairnloop, :max_batch_size, 25)

  defp default_auditor do
    Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
  end

  @doc """
  Triggers an outbound message for a given conversation.

  ## Options
    * `:template_id` (required) - The identifier for the template to use.
    * `:content` (optional) - The content of the message. Defaults to a template reference.
    * `:schedule_in` (optional) - Delay in seconds before sending the message.
    * `:actor` (optional) - The entity triggering the outbound action for auditing.
    * `:auditor` (optional) - Custom auditor implementation.
    * `:bulk_envelope_id` (optional, Phase 25 additive — D-12) - When set, this
      correlation key is threaded into `Message.metadata["bulk_envelope_id"]` and
      into the `OutboundWorker` job args so the per-recipient delivery participates
      in the bulk audit envelope and the Oban `unique:` dedup tuple
      `(conversation_id, template_id, bulk_envelope_id)` (D-11).

  ## Telemetry (D-B enum-only labels — WR-04)

  `[:cairnloop, :outbound, :triggered, :start | :stop | :exception]` is emitted
  with metadata containing ONLY `outcome :: :triggered` (enum-only). The
  per-recipient `conversation_id`, `template_id`, `actor`, and `schedule_in`
  facts live in the durable `Message` row, the `OutboundWorker` job args, and
  the auditor metadata — NEVER in telemetry labels. This protects attached
  Prometheus / StatsD / Datadog handlers from cardinality explosion and PII
  leakage; Phase 25 bulk fan-out routes through this lane per-recipient, so a
  25-recipient bulk emits 25 enum-only events. A host that genuinely needs
  per-recipient audit by actor should attach to the auditor's
  `:outbound_trigger` event instead.
  """
  def trigger(conversation_id, opts) do
    template_id = Keyword.fetch!(opts, :template_id)
    _schedule_in = Keyword.get(opts, :schedule_in)
    actor = Keyword.get(opts, :actor)
    auditor = Keyword.get(opts, :auditor, default_auditor())

    # WR-04 / D-B: telemetry metadata is enum-only — NO `actor`,
    # `conversation_id`, `template_id`, or `schedule_in` in labels (those would
    # explode cardinality on Prometheus / StatsD / Datadog and leak PII to any
    # attached telemetry handler). Phase 25 bulk fan-out routes through this
    # `trigger/2` lane per-recipient, so a 25-recipient bulk previously emitted
    # 25 events EACH carrying conversation_id + actor — fixed here at the
    # source. The high-cardinality + PII facts still live in the durable
    # `Message` row, the per-recipient `OutboundWorker` job args, and the
    # auditor metadata below; a host that genuinely needs per-recipient audit
    # by actor should attach to the auditor's `:outbound_trigger` event, not
    # to `:telemetry`. See `Cairnloop.Outbound.bulk_trigger/2`'s telemetry
    # which has always been enum-only.
    telemetry_meta = %{outcome: :triggered}

    # Phase 26 D-03: OI trace lane — additive, fire-and-forget, around the sealed
    # bounded-metrics span. Rescue path emits :trigger_failed with outcome: :exception
    # then reraises (mirrors :telemetry.span/3 :exception semantics; never swallows).
    trace_attrs = %{
      conversation_id: conversation_id,
      template_id: template_id,
      actor_id: actor,
      outcome: :triggered,
      bulk_envelope_id: Keyword.get(opts, :bulk_envelope_id)
    }

    Traces.emit(:trigger_started, trace_attrs)

    try do
      span_result =
        Cairnloop.Telemetry.span([:outbound, :triggered], telemetry_meta, fn ->
          multi =
            conversation_id
            |> build_trigger_multi(opts)
            |> auditor.audit(:outbound_trigger, actor, %{
              conversation_id: conversation_id,
              template_id: template_id
            })

          result = repo().transaction(multi)
          {result, telemetry_meta}
        end)

      case span_result do
        {:ok, _} ->
          Traces.emit(:trigger_completed, %{trace_attrs | outcome: :triggered})

        # Both {:error, reason} and Ecto.Multi's {:error, name, value, changes} are
        # observed — they all map to the OI :trigger_failed outcome.
        {:error, _} ->
          Traces.emit(:trigger_failed, %{trace_attrs | outcome: :failed})

        {:error, _name, _value, _changes} ->
          Traces.emit(:trigger_failed, %{trace_attrs | outcome: :failed})
      end

      span_result
    rescue
      e ->
        Traces.emit(:trigger_failed, %{trace_attrs | outcome: :exception})
        reraise(e, __STACKTRACE__)
    end
  end

  # Shared per-recipient multi-builder (research Open Question 1). Returns an
  # `Ecto.Multi` WITHOUT executing it so both `trigger/2` and `bulk_trigger/2` can
  # compose it without nesting transactions and without breaking `trigger/2`'s
  # sealed public contract (D-12).
  #
  # When `:multi_key_prefix` is `nil` (single-recipient `trigger/2` path), the
  # per-step keys remain `:message` and `:delivery_job` exactly as the Phase 22/23
  # regression tests expect. When set (bulk fan-out), the keys become
  # `:"message_#{prefix}"` and `:"delivery_job_#{prefix}"` so the merged multi has
  # unique keys per recipient.
  defp build_trigger_multi(conversation_id, opts) do
    template_id = Keyword.fetch!(opts, :template_id)
    content = Keyword.get(opts, :content, "Outbound message using template: #{template_id}")
    schedule_in = Keyword.get(opts, :schedule_in)
    bulk_envelope_id = Keyword.get(opts, :bulk_envelope_id)
    key_prefix = Keyword.get(opts, :multi_key_prefix)

    {message_key, job_key} =
      case key_prefix do
        nil -> {:message, :delivery_job}
        p -> {:"message_#{p}", :"delivery_job_#{p}"}
      end

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      message_key,
      Message.changeset(%Message{}, %{
        conversation_id: conversation_id,
        content: content,
        role: :system_outbound,
        metadata: %{
          "template_id" => template_id,
          "status" => "pending",
          "bulk_envelope_id" => bulk_envelope_id
        }
      })
    )
    |> Ecto.Multi.merge(fn changes ->
      message = Map.fetch!(changes, message_key)
      job_opts = if schedule_in, do: [schedule_in: schedule_in], else: []

      job_args = %{
        "message_id" => message.id,
        "conversation_id" => conversation_id,
        "template_id" => template_id,
        "bulk_envelope_id" => bulk_envelope_id
      }

      Ecto.Multi.insert(
        Ecto.Multi.new(),
        job_key,
        Cairnloop.Workers.OutboundWorker.new(job_args, job_opts)
      )
    end)
  end

  @doc """
  Bulk-triggers outbound messages across N conversations under a single durable
  `Cairnloop.Outbound.BulkEnvelope` row (D-13). Per-recipient delivery flows through
  the sealed `Outbound.trigger/2` lane via the shared private `build_trigger_multi/2`
  helper (research Open Question 1).

  **The caller is responsible for rendering** the template body and passing it as
  `:rendered_body`. `bulk_trigger/2` NEVER re-resolves the template — the envelope
  persists exactly the string the caller passed (CLAUDE.md "snapshot trust facts at
  decision time"; T-25-03 mitigation).

  ## Options

    * `:template_id` (required) - The template id that was rendered into `:rendered_body`.
      Persisted on the envelope for audit; NEVER used to re-render.
    * `:rendered_body` (required) - The pre-rendered message body, snapshotted on the
      envelope row at confirmation time.
    * `:actor` (optional) - Actor string (operator, system, etc.); recorded as
      `requested_by` on the envelope.
    * `:auditor` (optional) - Custom auditor implementation. Defaults to the configured
      `:cairnloop, :auditor`.

  ## Cap (D-09, defense-in-depth — research Pitfall 4)

  If `length(conversation_ids) > max_batch_size()`, a `BulkEnvelope` row is still
  inserted with `status: :refused_cap_exceeded` and a humanized `:refused_reason`
  (research Open Question 5 — mirrors `Governance.propose_blocked` posture so OBS-02
  reads see both lanes from one table). The function then returns
  `{:error, :batch_too_large}` and emits a telemetry event with
  `outcome: :refused_cap_exceeded`.

  ## Telemetry (D-B enum-only labels)

  `[:cairnloop, :outbound, :bulk, :triggered]` is emitted with metadata containing
  ONLY `outcome :: :submitted | :refused_cap_exceeded` and `count` — `template_id`,
  recipient identifiers, and actor are NEVER in telemetry labels (research Pitfall 5).
  Those live in the durable envelope row and the auditor metadata.
  """
  def bulk_trigger(conversation_ids, opts) when is_list(conversation_ids) do
    template_id = Keyword.fetch!(opts, :template_id)
    rendered_body = Keyword.fetch!(opts, :rendered_body)
    actor = Keyword.get(opts, :actor)
    auditor = Keyword.get(opts, :auditor, default_auditor())

    count = length(conversation_ids)
    cap = max_batch_size()

    if count > cap do
      bulk_trigger_refused(conversation_ids, template_id, rendered_body, actor, count, cap)
    else
      # WR-05: thread the cap through to the submit lane so it lands on the
      # `:effective_cap` envelope column alongside the refused lane.
      bulk_trigger_submit(conversation_ids, template_id, rendered_body, actor, auditor, cap, opts)
    end
  end

  # D-09 fail-closed refusal. Persists a durable `:refused_cap_exceeded` envelope row
  # so OBS-02 can audit oversized-cohort attempts (research Open Question 5). Emits
  # telemetry with enum-only labels per D-B; returns `{:error, :batch_too_large}`.
  defp bulk_trigger_refused(conversation_ids, template_id, rendered_body, actor, count, cap) do
    envelope_id = Ecto.UUID.generate()

    envelope_attrs = %{
      id: envelope_id,
      template_id: template_id,
      rendered_body: rendered_body,
      recipient_conversation_ids: conversation_ids,
      count: count,
      # WR-05: snapshot the cap that was in effect at decision time so OBS-02
      # readers see the policy of the moment, not whatever `max_batch_size/0`
      # returns at audit-read time.
      effective_cap: cap,
      requested_by: actor,
      requested_at: DateTime.utc_now(),
      status: :refused_cap_exceeded,
      refused_reason: "batch_size #{count} exceeds cap #{cap}"
    }

    # Insert the refusal envelope OUTSIDE the telemetry span so the audit row lands
    # even if the caller has no telemetry handler attached.
    #
    # CR-02: the audit-write result MUST be observed. If the insert fails
    # (Postgres outage, changeset error, unique-constraint collision, etc.),
    # silently swallowing it would defeat the OBS-02 "refused attempts persist"
    # guarantee the moduledoc + `BulkEnvelope` @moduledoc both advertise. We
    # still return `{:error, :batch_too_large}` so the LiveView's calm refusal
    # copy fires (the operator-visible behavior is unchanged), but we surface
    # the audit failure through a structured log line AND a distinct telemetry
    # outcome (`:refused_cap_exceeded_audit_failed`) so attached handlers can
    # alert. Mirrors `Governance.propose_blocked/5` which also surfaces (rather
    # than swallows) insert failures.
    # Phase 26 D-03: per RESEARCH OQ3 the OI lane carries :effective_cap on
    # :bulk_refused events; on each refusal arm the OI trace fires AFTER the
    # bounded-metrics execute call, matching the canonical "Telemetry then Traces"
    # pattern (lib/cairnloop/governance.ex:380-392).
    refused_trace_attrs = %{
      bulk_envelope_id: envelope_id,
      template_id: template_id,
      actor_id: actor,
      conversation_id: nil,
      effective_cap: cap
    }

    case repo().insert(BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs)) do
      {:ok, _envelope} ->
        Cairnloop.Telemetry.execute(
          [:outbound, :bulk, :triggered],
          %{count: count},
          %{outcome: :refused_cap_exceeded, count: count}
        )

        Traces.emit(:bulk_refused, Map.put(refused_trace_attrs, :outcome, :refused_cap_exceeded))

      {:error, %Ecto.Changeset{} = changeset} ->
        # `inspect/1` on the changeset's `.errors` keyword list is acceptable
        # in a Logger line — T-15-13 forbids it for durable operator-visible
        # columns; this is a structured diagnostic for ops, not operator copy.
        require Logger

        Logger.error(
          "BulkEnvelope refusal insert failed: #{inspect(changeset.errors)}"
        )

        Cairnloop.Telemetry.execute(
          [:outbound, :bulk, :triggered],
          %{count: count},
          %{outcome: :refused_cap_exceeded_audit_failed, count: count}
        )

        Traces.emit(
          :bulk_refused,
          Map.put(refused_trace_attrs, :outcome, :refused_cap_exceeded_audit_failed)
        )

      other ->
        # Non-changeset error path (exotic repo() shapes). Keep observability
        # symmetric so OBS-02 can detect the gap regardless of failure mode.
        require Logger

        Logger.error(
          "BulkEnvelope refusal insert returned unexpected shape: #{inspect(other)}"
        )

        Cairnloop.Telemetry.execute(
          [:outbound, :bulk, :triggered],
          %{count: count},
          %{outcome: :refused_cap_exceeded_audit_failed, count: count}
        )

        Traces.emit(
          :bulk_refused,
          Map.put(refused_trace_attrs, :outcome, :refused_cap_exceeded_audit_failed)
        )
    end

    {:error, :batch_too_large}
  end

  # D-13 happy path. Single `Ecto.Multi`: envelope insert + per-recipient
  # `build_trigger_multi/2` merge + auditor step. Wrapped in a telemetry span with
  # enum-only labels (D-B / Pitfall 5).
  defp bulk_trigger_submit(conversation_ids, template_id, rendered_body, actor, auditor, cap, opts) do
    envelope_id = Ecto.UUID.generate()
    count = length(conversation_ids)

    envelope_attrs = %{
      id: envelope_id,
      template_id: template_id,
      rendered_body: rendered_body,
      recipient_conversation_ids: conversation_ids,
      count: count,
      # WR-05: snapshot the cap that was in effect at decision time. Lets OBS-02
      # readers compare `count` against the policy of the moment even if ops
      # tune `:cairnloop, :max_batch_size` between attempts.
      effective_cap: cap,
      requested_by: actor,
      requested_at: DateTime.utc_now(),
      status: :submitted
    }

    # Strip caller-provided :bulk_envelope_id / :multi_key_prefix; we own those here.
    per_recipient_opts =
      opts
      |> Keyword.delete(:bulk_envelope_id)
      |> Keyword.delete(:multi_key_prefix)

    # D-B / Pitfall 5: telemetry metadata is enum-only — no template_id, no actor,
    # no recipient identifiers in labels.
    Cairnloop.Telemetry.span([:outbound, :bulk, :triggered], %{outcome: :submitted, count: count}, fn ->
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:envelope, BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs))
        |> Ecto.Multi.merge(fn %{envelope: env} ->
          Enum.reduce(conversation_ids, Ecto.Multi.new(), fn cid, acc ->
            recipient_opts =
              per_recipient_opts
              |> Keyword.put(:bulk_envelope_id, env.id)
              |> Keyword.put(:multi_key_prefix, cid)

            Ecto.Multi.append(acc, build_trigger_multi(cid, recipient_opts))
          end)
        end)
        |> auditor.audit(:bulk_outbound_trigger, actor, %{
          bulk_envelope_id: envelope_id,
          count: count,
          template_id: template_id
        })

      result = repo().transaction(multi)

      # Phase 26 D-03: OI trace lane — bulk envelope is the unit of work; per-recipient
      # traces fire from OutboundWorker.perform/1. Emitted inside the sealed span's `fn`
      # so the OI trace ships AFTER the transaction result is known.
      Traces.emit(:bulk_submitted, %{
        bulk_envelope_id: envelope_id,
        template_id: template_id,
        actor_id: actor,
        outcome: :submitted,
        conversation_id: nil
      })

      # Telemetry metadata for the :stop event stays enum-only (D-B).
      {result, %{outcome: :submitted, count: count}}
    end)
  end
end
