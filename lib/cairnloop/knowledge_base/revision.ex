defmodule Cairnloop.KnowledgeBase.Revision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_revisions" do
    field(:content, :string)
    field(:version, :integer, default: 1)
    field(:state, Ecto.Enum, values: [:draft, :published, :archived], default: :draft)

    belongs_to(:article, Cairnloop.KnowledgeBase.Article)
    has_many(:chunks, Cairnloop.KnowledgeBase.Chunk)

    timestamps()
  end

  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [:content, :version, :state, :article_id])
    |> validate_required([:content, :version, :state, :article_id])
    |> enforce_immutability()
  end

  defp enforce_immutability(changeset) do
    # If the revision was already published in the database, block content changes.
    if changeset.data.id && changeset.data.state == :published do
      if get_change(changeset, :content) do
        add_error(changeset, :content, "cannot be modified after publication")
      else
        changeset
      end
    else
      changeset
    end
  end
end
