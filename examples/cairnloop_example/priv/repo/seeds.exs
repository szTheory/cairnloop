# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CairnloopExample.Repo.insert!(%CairnloopExample.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Create a dummy conversation using direct Repo insertion
{:ok, conversation} =
  %Cairnloop.Conversation{}
  |> Ecto.Changeset.change(%{
    status: :open, 
    subject: "Demo Customer Request", 
    host_user_id: "demo_user"
  })
  |> CairnloopExample.Repo.insert()

{:ok, _message} =
  %Cairnloop.Message{}
  |> Ecto.Changeset.change(%{
    conversation_id: conversation.id,
    content: "I need help with my account, can you reset my billing?",
    role: :user,
    metadata: %{}
  })
  |> CairnloopExample.Repo.insert()

{:ok, article} = 
  %Cairnloop.KnowledgeBase.Article{}
  |> Ecto.Changeset.change(%{
    title: "How to reset billing",
    status: :published
  })
  |> CairnloopExample.Repo.insert()

{:ok, _revision} =
  %Cairnloop.KnowledgeBase.Revision{}
  |> Ecto.Changeset.change(%{
    article_id: article.id,
    content: "To reset billing, go to settings and click reset.",
    version: 1,
    state: :published
  })
  |> CairnloopExample.Repo.insert()

