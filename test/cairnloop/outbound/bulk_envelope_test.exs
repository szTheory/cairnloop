defmodule Cairnloop.Outbound.BulkEnvelopeTest do
  @moduledoc """
  Headless schema tests for `Cairnloop.Outbound.BulkEnvelope` — Phase 25 plan 01 (D-13).

  These tests are pure (no DB) so they run cleanly even when `Cairnloop.Repo` is
  REPO-UNAVAILABLE in this workspace (CLAUDE.md / D-16).
  """
  use ExUnit.Case, async: true

  alias Cairnloop.Outbound.BulkEnvelope

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @required_fields [
    :id,
    :template_id,
    :rendered_body,
    :recipient_conversation_ids,
    :count,
    # WR-05: snapshot of `max_batch_size/0` at decision time. Required so
    # OBS-02 readers can compare `count` against the policy of the moment.
    :effective_cap,
    :requested_at
  ]

  defp valid_attrs(overrides \\ %{}) do
    base = %{
      id: Ecto.UUID.generate(),
      template_id: "recovery_v1",
      rendered_body: "We're following up to see how things are going.",
      recipient_conversation_ids: [101, 102, 103],
      count: 3,
      # WR-05: matches the v1 default `max_batch_size = 25` from D-09.
      effective_cap: 25,
      requested_by: "ops_user_1",
      requested_at: DateTime.utc_now()
    }

    Map.merge(base, overrides)
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "is valid when all required fields are present (Test 1)" do
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, valid_attrs())

      assert changeset.valid?,
             "expected valid changeset; got errors: #{inspect(changeset.errors)}"
    end

    test "is invalid when any required field is missing (Test 2)" do
      # Drop one required field at a time and assert that field shows up as an error.
      # Concise: iterate the required-field list instead of writing N separate tests
      # (Nyquist — small set, single shape).
      for field <- @required_fields do
        attrs = valid_attrs() |> Map.delete(field)
        changeset = BulkEnvelope.changeset(%BulkEnvelope{}, attrs)

        refute changeset.valid?, "expected invalid changeset when #{field} is missing"

        assert Keyword.has_key?(changeset.errors, field),
               "expected error on field #{field}; got #{inspect(changeset.errors)}"
      end
    end

    test "is invalid when count is 0 (Test 3 — validate_number greater_than: 0)" do
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, valid_attrs(%{count: 0}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :count)
    end

    test "is invalid when effective_cap is 0 (WR-05 — validate_number greater_than: 0)" do
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, valid_attrs(%{effective_cap: 0}))
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :effective_cap)
    end

    test "effective_cap snapshot is preserved through cast/apply_changes (WR-05)" do
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, valid_attrs(%{effective_cap: 25}))
      assert changeset.valid?
      applied = Ecto.Changeset.apply_changes(changeset)
      assert applied.effective_cap == 25
    end

    test "status defaults to :submitted; refused_cap_exceeded + reason is valid (Test 4)" do
      # Default status is :submitted on a freshly built envelope.
      assert %BulkEnvelope{status: :submitted} = %BulkEnvelope{}

      # Setting status: :refused_cap_exceeded with a refused_reason string is valid.
      attrs =
        valid_attrs(%{
          status: :refused_cap_exceeded,
          refused_reason: "Batch exceeds the safe send limit of 25."
        })

      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, attrs)

      assert changeset.valid?,
             "expected valid refusal changeset; got #{inspect(changeset.errors)}"

      applied = Ecto.Changeset.apply_changes(changeset)
      assert applied.status == :refused_cap_exceeded
      assert applied.refused_reason == "Batch exceeds the safe send limit of 25."
    end

    test "recipient_conversation_ids accepts a list of integers (Test 5 — positive case)" do
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, valid_attrs())
      assert changeset.valid?
      applied = Ecto.Changeset.apply_changes(changeset)
      assert applied.recipient_conversation_ids == [101, 102, 103]
    end

    test "recipient_conversation_ids rejects a non-list value (Test 5 — negative case)" do
      attrs = valid_attrs(%{recipient_conversation_ids: "not-a-list"})
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :recipient_conversation_ids)
    end

    test "recipient_conversation_ids rejects a list with non-integer elements (Test 5 — element type)" do
      attrs = valid_attrs(%{recipient_conversation_ids: ["abc", :not_an_int]})
      changeset = BulkEnvelope.changeset(%BulkEnvelope{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :recipient_conversation_ids)
    end
  end
end
