defmodule Cairnloop.Integration.GovernedActionsPaginationTest do
  @moduledoc """
  Integration coverage for the governed-actions rail pagination (TECH-01) — Phase 35 UAT
  check 4. Mounts `Cairnloop.Web.ConversationLive` for real against a Postgres-backed
  conversation with more proposals than one page, and asserts the "Load more" affordance
  pages through them via plain assigns (D-02: no streams).

  Asserts the decisive, deterministic behavior — the number of rendered governed-action
  cards and the button's presence — rather than which specific proposal lands on which
  page (`list_proposals_for_conversation/2` orders by inserted_at with no id tiebreaker, so
  rows sharing a microsecond could reorder; the count/limit logic is what TECH-01 promises).
  """
  use Cairnloop.ConnCase, async: false

  import Cairnloop.Fixtures
  import Phoenix.LiveViewTest

  defmodule StubContextProvider do
    def get_context(_host_user_id, _opts), do: {:ok, %{}}
  end

  setup %{conn: conn} do
    Application.put_env(:cairnloop, :context_provider, StubContextProvider)
    on_exit(fn -> Application.delete_env(:cairnloop, :context_provider) end)

    conversation = conversation_fixture(%{host_user_id: "operator_7"})

    # 25 proposals tied to the conversation — more than 2 pages at the limit-10 page size.
    for n <- 1..25 do
      proposal_fixture(%{
        conversation_id: conversation.id,
        rendered_consequence: "Governed refund ##{n}."
      })
    end

    %{conn: conn, conversation: conversation}
  end

  # Each governed-action card renders `<section class="rail-card governed-action-card" ...>`;
  # the only other "governed-action-card" occurrence is the CSS selector in the <style> block,
  # which does not contain the full class-attribute string we split on.
  defp card_count(html) do
    html
    |> String.split(~s(class="rail-card governed-action-card"))
    |> length()
    |> Kernel.-(1)
  end

  test "the rail shows one page, then pages to the rest via Load more", ctx do
    {:ok, view, html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

    # First page: limit 10 → 10 cards rendered, "Load more" present (length == limit).
    assert card_count(html) == 10
    assert has_element?(view, "button[phx-click='load_more_actions']")

    # One "Load more" → limit 20 → 20 cards, button still present (20 == limit 20).
    html = view |> element("button[phx-click='load_more_actions']") |> render_click()
    assert card_count(html) == 20
    assert has_element?(view, "button[phx-click='load_more_actions']")

    # Second "Load more" → limit 30 → only 25 exist → all 25 shown, button gone (25 != 30).
    html = view |> element("button[phx-click='load_more_actions']") |> render_click()
    assert card_count(html) == 25
    refute has_element?(view, "button[phx-click='load_more_actions']")
  end

  test "the rail shows no Load more button when proposals fit in one page", %{conn: conn} do
    small = conversation_fixture(%{host_user_id: "operator_8"})

    for n <- 1..3 do
      proposal_fixture(%{conversation_id: small.id, rendered_consequence: "Small ##{n}."})
    end

    {:ok, view, html} = live(conn, "/governance/#{small.id}")

    assert card_count(html) == 3
    refute has_element?(view, "button[phx-click='load_more_actions']")
  end
end
