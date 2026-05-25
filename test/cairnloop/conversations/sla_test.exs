defmodule Cairnloop.Conversations.SLATest do
  use ExUnit.Case, async: true
  alias Cairnloop.Conversations.SLA

  describe "changeset/2" do
    test "validates required fields" do
      changeset = SLA.changeset(%SLA{}, %{})

      assert %{
               status: ["can't be blank"],
               target_type: ["can't be blank"],
               target_at: ["can't be blank"],
               conversation_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "enforces enum values for target_type and status" do
      changeset =
        SLA.changeset(%SLA{}, %{
          status: :invalid_status,
          target_type: :invalid_type,
          target_at: DateTime.utc_now(),
          conversation_id: 1
        })

      assert %{
               status: ["is invalid"],
               target_type: ["is invalid"]
             } = errors_on(changeset)

      valid_changeset =
        SLA.changeset(%SLA{}, %{
          status: :active,
          target_type: :first_response,
          target_at: DateTime.utc_now(),
          conversation_id: 1
        })

      assert valid_changeset.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
