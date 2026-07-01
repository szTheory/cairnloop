defmodule Cairnloop.Web.MotionCSSTest do
  @moduledoc """
  Phase 44 motion guardrails.

  These are DB-free source/CSS checks. They pin the shared motion primitives,
  reduced-motion behavior, example-app import strategy, and the specific UI
  surfaces that are allowed to opt into motion.
  """

  use ExUnit.Case, async: true

  @css_path Path.expand("../../../priv/static/cairnloop.css", __DIR__)
  @app_css_path Path.expand("../../../examples/cairnloop_example/assets/css/app.css", __DIR__)
  @components_path Path.expand("../../../lib/cairnloop/web/components.ex", __DIR__)
  @inbox_path Path.expand("../../../lib/cairnloop/web/inbox_live.ex", __DIR__)
  @conversation_path Path.expand("../../../lib/cairnloop/web/conversation_live.ex", __DIR__)
  @layouts_path Path.expand(
                  "../../../examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex",
                  __DIR__
                )
  @motion_e2e_path Path.expand(
                     "../../../examples/cairnloop_example/test/e2e/motion_test.exs",
                     __DIR__
                   )

  @keyframes ~w(cl-enter-up cl-reveal-x cl-toast-enter cl-toast-exit)
  @motion_classes ~w(
    .cl-motion-enter
    .cl-motion-reveal
    .cl-motion-state
    .cl-list-stagger
    .cl-toast-enter
    .cl-toast-exit
    .cl-toast
  )

  @layout_property ~r/(^|[;\s])(?:display|position|width|height|min-width|max-width|min-height|max-height|margin(?:-[a-z]+)?|padding(?:-[a-z]+)?|top|right|bottom|left|inset(?:-[a-z]+)?|grid(?:-[a-z]+)?|flex(?:-[a-z]+)?)\s*:/m
  @unsafe_transition_property ~r/transition-property:\s*[^;]*(?:all|width|height|min-width|max-width|min-height|max-height|margin|padding|top|right|bottom|left|inset|grid|flex)/m

  test "shared CSS defines the Phase 44 motion primitives" do
    css = File.read!(@css_path)

    for token <-
          ~w(--cl-dur-instant --cl-dur-micro --cl-dur-ui --cl-dur-panel --cl-dur-exit --cl-ease-out --cl-ease-drawer --cl-stagger) do
      assert css =~ token, "missing motion token #{token}"
    end

    for keyframe <- @keyframes do
      assert css =~ "@keyframes #{keyframe}", "missing #{keyframe}"
      body = extract_block!(css, "@keyframes #{keyframe}")

      refute Regex.match?(@layout_property, body),
             "#{keyframe} must only animate transform/opacity, not layout properties"

      assert body =~ "opacity"
      assert body =~ "transform"
    end

    for selector <- @motion_classes do
      assert css =~ selector, "missing motion selector #{selector}"
    end
  end

  test "motion transitions avoid layout properties and count ticks do not animate" do
    css = File.read!(@css_path)

    state_body = extract_block!(css, ".cl-motion-state")

    assert state_body =~
             "transition-property: opacity, color, background-color, border-color"

    refute Regex.match?(@unsafe_transition_property, state_body),
           "cl-motion-state may cross-fade state but must not transition layout properties"

    for selector <- [".cl-hero__count", ".cl-stat__count"] do
      body = extract_block!(css, selector)

      refute body =~ "transition:",
             "#{selector} must not animate count ticks directly"

      refute body =~ "transition-property",
             "#{selector} must not animate count ticks directly"

      refute body =~ "animation",
             "#{selector} must not animate count ticks directly"
    end
  end

  test "reduced motion suppresses movement but keeps meaning-bearing state cross-fades" do
    css = File.read!(@css_path)
    reduced = extract_block!(css, "@media (prefers-reduced-motion: reduce)")

    assert reduced =~ ".cl-toast",
           "toasts render outside .cl-app in the example layout and must be covered by reduced motion"

    assert reduced =~ ".cl-motion-state"
    assert reduced =~ "transition-duration: 120ms !important"

    assert reduced =~
             "transition-property: opacity, color, background-color, border-color !important"
  end

  test "example app imports the library CSS instead of forking motion rules" do
    app_css = File.read!(@app_css_path)

    assert app_css =~ ~s|@import "../../../../priv/static/cairnloop.css";|

    refute app_css =~ "@keyframes cl-enter-up"
    refute app_css =~ ".cl-motion-enter"
    refute app_css =~ ".cl-list-stagger"
  end

  test "allowed UI surfaces are wired to the shared motion primitives" do
    components = File.read!(@components_path)
    inbox = File.read!(@inbox_path)
    conversation = File.read!(@conversation_path)
    layouts = File.read!(@layouts_path)

    assert components =~ "alias Phoenix.LiveView.JS"
    assert components =~ "def cl_flash"
    assert components =~ ~s|JS.transition("cl-motion-enter", time: 140)|
    assert components =~ ~s|JS.transition("cl-toast-enter", time: 180)|
    assert components =~ ~s|JS.transition("cl-toast-exit", time: 160)|

    assert layouts =~ "import Cairnloop.Web.Components, only: [cl_flash: 1]"
    assert layouts =~ "<.cl_flash kind={:info}"
    assert layouts =~ "<.cl_flash kind={:error}"

    assert inbox =~ "cl-inbox-list--bulk-clearance cl-list-stagger"

    assert conversation =~ ~s|JS.transition("cl-motion-reveal", time: 260)|

    assert conversation =~
             ~s|["message-status-chip", outbound_status_class(msg), "cl-motion-state"]|

    reply_region =
      source_region!(
        conversation,
        ~s(<div class="reply-form"),
        ~s(<div\n          class="evidence-rail")
      )

    refute reply_region =~ "cl-motion",
           "reply-send path must stay immediate and must not gain decorative motion"
  end

  test "browser E2E guard for motion remains wired into the gated lane" do
    assert File.exists?(@motion_e2e_path),
           "expected examples/cairnloop_example/test/e2e/motion_test.exs to exist"

    src = File.read!(@motion_e2e_path)

    assert src =~ "@moduletag :e2e"
    assert src =~ "getComputedStyle"
    assert src =~ "reduced_motion"
    assert src =~ "prefers-reduced-motion"
  end

  defp extract_block!(source, marker) do
    start =
      case :binary.match(source, marker) do
        {pos, _len} -> pos
        :nomatch -> flunk("missing CSS block marker #{inspect(marker)}")
      end

    source_after_marker = binary_part(source, start, byte_size(source) - start)

    open_offset =
      case :binary.match(source_after_marker, "{") do
        {pos, _len} -> pos
        :nomatch -> flunk("missing opening brace for #{inspect(marker)}")
      end

    body_start = start + open_offset + 1
    body = binary_part(source, body_start, byte_size(source) - body_start)

    collect_until_balanced(body, 1, [])
  end

  defp collect_until_balanced(<<"{", rest::binary>>, depth, acc),
    do: collect_until_balanced(rest, depth + 1, [acc, "{"])

  defp collect_until_balanced(<<"}", _rest::binary>>, 1, acc), do: IO.iodata_to_binary(acc)

  defp collect_until_balanced(<<"}", rest::binary>>, depth, acc),
    do: collect_until_balanced(rest, depth - 1, [acc, "}"])

  defp collect_until_balanced(<<char::utf8, rest::binary>>, depth, acc),
    do: collect_until_balanced(rest, depth, [acc, <<char::utf8>>])

  defp collect_until_balanced(<<>>, _depth, acc), do: IO.iodata_to_binary(acc)

  defp source_region!(source, start_marker, end_marker) do
    {start, _} = :binary.match(source, start_marker)
    after_start = binary_part(source, start, byte_size(source) - start)
    {finish, _} = :binary.match(after_start, end_marker)
    binary_part(source, start, finish)
  end
end
