defmodule CairnloopExampleWeb.MotionE2ETest do
  @moduledoc """
  Real-browser proof for Phase 44 motion contracts that source tests cannot
  fully cover: the shipped CSS resolves on actual operator pages, and the
  persistent motion classes are present on rendered elements.
  """

  use PhoenixTest.Playwright.Case,
    async: false,
    browser_context_opts: [viewport: %{width: 1024, height: 720}]

  @moduletag :e2e

  import CairnloopExample.RailFixtures

  alias Cairnloop.Message
  alias CairnloopExample.Repo

  setup do
    %{conv_id: conv_id} = pending_governed_action_conversation()
    insert_outbound_message(conv_id, "sent")
    resolved_inbox_rows(3)

    %{conv_id: conv_id}
  end

  test "state and list motion primitives resolve in the browser", %{conn: conn, conv_id: conv_id} do
    conn =
      conn
      |> visit("/support/#{conv_id}")
      |> assert_has("body .phx-connected")
      |> assert_has(".message-status-chip.cl-motion-state")

    evaluate(
      conn,
      """
      (() => {
        const chip = document.querySelector('.message-status-chip.cl-motion-state');
        const cs = window.getComputedStyle(chip);
        return {
          transitionProperty: cs.transitionProperty,
          transitionDurationMs: durationMs(cs.transitionDuration)
        };

        function durationMs(value) {
          const first = value.split(',')[0].trim();
          return first.endsWith('ms') ? parseFloat(first) : parseFloat(first) * 1000;
        }
      })()
      """,
      fn result ->
        assert result["transitionProperty"] =~ "opacity"
        assert result["transitionProperty"] =~ "background-color"
        assert result["transitionDurationMs"] >= 100
        assert result["transitionDurationMs"] <= 250
      end
    )

    conn =
      conn
      |> visit("/support/inbox")
      |> assert_has("body .phx-connected")
      |> assert_has(".cl-list-stagger > li")

    evaluate(
      conn,
      """
      (() => {
        const row = document.querySelector('.cl-list-stagger > li');
        const cs = window.getComputedStyle(row);
        return {
          animationName: cs.animationName,
          animationDurationMs: durationMs(cs.animationDuration)
        };

        function durationMs(value) {
          const first = value.split(',')[0].trim();
          return first.endsWith('ms') ? parseFloat(first) : parseFloat(first) * 1000;
        }
      })()
      """,
      fn result ->
        assert result["animationName"] == "cl-enter-up"
        assert result["animationDurationMs"] >= 100
        assert result["animationDurationMs"] <= 250
      end
    )
  end

  defp insert_outbound_message(conv_id, status) do
    %Message{}
    |> Message.changeset(%{
      role: :system_outbound,
      conversation_id: conv_id,
      content: "Recovery follow-up queued by motion E2E.",
      metadata: %{"template_id" => "motion_e2e", "status" => status}
    })
    |> Repo.insert!()
  end
end

defmodule CairnloopExampleWeb.ReducedMotionE2ETest do
  @moduledoc """
  Real-browser reduced-motion proof for Phase 44.
  """

  use PhoenixTest.Playwright.Case,
    async: false,
    browser_context_opts: [
      viewport: %{width: 1024, height: 720},
      reduced_motion: :reduce
    ]

  @moduletag :e2e

  import CairnloopExample.RailFixtures

  alias Cairnloop.Message
  alias CairnloopExample.Repo

  setup do
    %{conv_id: conv_id} = pending_governed_action_conversation()
    insert_outbound_message(conv_id, "failed")
    resolved_inbox_rows(3)

    %{conv_id: conv_id}
  end

  test "reduced motion suppresses movement and keeps the state cross-fade", %{
    conn: conn,
    conv_id: conv_id
  } do
    conn =
      conn
      |> visit("/support/inbox")
      |> assert_has("body .phx-connected")
      |> assert_has(".cl-list-stagger > li")

    evaluate(
      conn,
      """
      (() => {
        const row = document.querySelector('.cl-list-stagger > li');
        const cs = window.getComputedStyle(row);
        return {
          prefersReduce: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
          animationDurationMs: durationMs(cs.animationDuration)
        };

        function durationMs(value) {
          const first = value.split(',')[0].trim();
          return first.endsWith('ms') ? parseFloat(first) : parseFloat(first) * 1000;
        }
      })()
      """,
      fn result ->
        assert result["prefersReduce"] == true
        assert result["animationDurationMs"] <= 1
      end
    )

    conn =
      conn
      |> visit("/support/#{conv_id}")
      |> assert_has("body .phx-connected")
      |> assert_has(".message-status-chip.cl-motion-state")

    evaluate(
      conn,
      """
      (() => {
        const chip = document.querySelector('.message-status-chip.cl-motion-state');
        const cs = window.getComputedStyle(chip);
        return {
          transitionProperty: cs.transitionProperty,
          transitionDurationMs: durationMs(cs.transitionDuration)
        };

        function durationMs(value) {
          const first = value.split(',')[0].trim();
          return first.endsWith('ms') ? parseFloat(first) : parseFloat(first) * 1000;
        }
      })()
      """,
      fn result ->
        assert result["transitionProperty"] =~ "opacity"
        assert result["transitionProperty"] =~ "background-color"
        assert result["transitionDurationMs"] <= 120
        assert result["transitionDurationMs"] >= 1
      end
    )
  end

  defp insert_outbound_message(conv_id, status) do
    %Message{}
    |> Message.changeset(%{
      role: :system_outbound,
      conversation_id: conv_id,
      content: "Recovery follow-up queued by reduced-motion E2E.",
      metadata: %{"template_id" => "motion_e2e", "status" => status}
    })
    |> Repo.insert!()
  end
end
