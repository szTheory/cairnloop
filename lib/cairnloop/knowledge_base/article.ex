defmodule Cairnloop.KnowledgeBase.Article do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  schema "cairnloop_articles" do
    field(:title, :string)
    field(:status, Ecto.Enum, values: [:draft, :published, :archived], default: :draft)

    has_many(:revisions, Cairnloop.KnowledgeBase.Revision)

    timestamps()
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :status])
    |> validate_required([:title, :status])
  end
end
