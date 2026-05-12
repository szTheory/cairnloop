defmodule Cairnloop.Automation.DraftTest do
  use ExUnit.Case, async: true
  alias Cairnloop.Automation.Draft

  describe "changeset/2" do
    test "requires content, status, and conversation_id" do
      changeset = Draft.changeset(%Draft{}, %{})

      assert %{
               content: ["can't be blank"],
               conversation_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "status only accepts valid values" do
      invalid_changeset =
        Draft.changeset(%Draft{}, %{
          content: "test",
          status: :unknown_status,
          conversation_id: 1
        })

      assert %{status: ["is invalid"]} = errors_on(invalid_changeset)

      valid_values = [:pending, :approved, :edited, :discarded]

      for status <- valid_values do
        changeset =
          Draft.changeset(%Draft{}, %{
            content: "test",
            status: status,
            conversation_id: 1
          })

        assert changeset.valid?
      end
    end
  end

  # Helper to get errors from a changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
