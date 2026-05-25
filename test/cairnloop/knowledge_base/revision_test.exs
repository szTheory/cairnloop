defmodule Cairnloop.KnowledgeBase.RevisionTest do
  use ExUnit.Case, async: true
  alias Cairnloop.KnowledgeBase.Revision

  describe "changeset/2" do
    test "allows valid initial creation" do
      attrs = %{content: "Initial", version: 1, state: :draft, article_id: 1}
      changeset = Revision.changeset(%Revision{}, attrs)
      assert changeset.valid?
    end

    test "allows content updates when state is draft" do
      revision = %Revision{id: 1, content: "Draft", state: :draft, article_id: 1, version: 1}
      changeset = Revision.changeset(revision, %{content: "Updated Draft"})
      assert changeset.valid?
    end

    test "rejects content updates when state is published" do
      revision = %Revision{
        id: 1,
        content: "Published",
        state: :published,
        article_id: 1,
        version: 1
      }

      changeset = Revision.changeset(revision, %{content: "Hacked!"})
      refute changeset.valid?
      assert "cannot be modified after publication" in errors_on(changeset).content
    end

    test "allows state updates (e.g. archiving) when state is published, but not content" do
      revision = %Revision{
        id: 1,
        content: "Published",
        state: :published,
        article_id: 1,
        version: 1
      }

      changeset = Revision.changeset(revision, %{state: :archived})
      assert changeset.valid?
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
