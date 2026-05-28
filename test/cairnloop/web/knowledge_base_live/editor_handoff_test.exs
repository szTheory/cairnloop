defmodule Cairnloop.Web.KnowledgeBaseLive.EditorHandoffTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation.EditorHandoff, as: Token
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff, as: Web

  setup do
    Application.put_env(
      :cairnloop,
      Cairnloop.KnowledgeAutomation.EditorHandoff,
      secret_key_base: "phase-30-test-secret-key-base-deterministic"
    )

    on_exit(fn ->
      Application.delete_env(:cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff)
    end)

    :ok
  end

  describe "Token.decode/1" do
    test "round-trips a domain-signed token, returns {:ok, payload} with string keys including manual_edit_opened_at" do
      token =
        Token.sign(%{
          suggestion_id: 15,
          article_id: 42,
          review_task_id: 7,
          return_to: "/knowledge-base/suggestions",
          manual_edit_opened_at: "2026-05-28T12:00:00.000000Z"
        })

      assert {:ok, payload} = Token.decode(token)
      assert is_map(payload)
      assert payload["suggestion_id"] == 15
      assert payload["article_id"] == 42
      assert payload["review_task_id"] == 7
      assert payload["return_to"] == "/knowledge-base/suggestions"
      assert payload["manual_edit_opened_at"] == "2026-05-28T12:00:00.000000Z"
    end

    test "returns {:error, _} for a garbage token" do
      assert {:error, _reason} = Token.decode("not-a-real-token")
    end
  end

  describe "Web.verify!/2" do
    test "returns :ok for a token signed with manual_edit_opened_at opt + matching params/article_id" do
      token =
        Web.sign(15, 42, nil, nil,
          manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
        )

      result = Web.verify!(%{"suggestion_id" => "15", "handoff" => token}, 42)
      assert result == :ok
    end

    test "raises Ecto.NoResultsError for a token signed WITHOUT the marker opt (bare suggestion_id handoff)" do
      token = Web.sign(15, 42, nil, nil)

      assert_raise Ecto.NoResultsError, fn ->
        Web.verify!(%{"suggestion_id" => "15", "handoff" => token}, 42)
      end
    end

    test "raises Ecto.NoResultsError when suggestion_id in params does not match signed token" do
      token =
        Web.sign(15, 42, nil, nil,
          manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
        )

      assert_raise Ecto.NoResultsError, fn ->
        Web.verify!(%{"suggestion_id" => "16", "handoff" => token}, 42)
      end
    end
  end
end
