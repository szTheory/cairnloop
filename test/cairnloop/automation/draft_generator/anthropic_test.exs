defmodule Cairnloop.Automation.DraftGenerator.AnthropicTest do
  @moduledoc """
  Headless unit coverage for the Anthropic reference draft generator. The Claude
  Messages API is stubbed via Req's `plug:` seam (`:anthropic_req_options`) — no
  network, no DB. Proves the fail-closed contract: a model-composed reply only on
  strong grounding + API key, and graceful delegation to the deterministic
  ScoriaEngine everywhere else.
  """
  use ExUnit.Case, async: false

  alias Cairnloop.Automation.DraftGenerator.Anthropic
  alias Cairnloop.Automation.ScoriaEngine

  @model_reply "Here is the grounded reply composed by the model."

  setup do
    # Stub the conversation loader so no Repo is needed for the prompt transcript.
    Application.put_env(:cairnloop, :conversation_lookup, fn _id ->
      %{messages: [%{role: :user, content: "How do I rotate my API key?"}]}
    end)

    on_exit(fn ->
      for key <- [
            :anthropic_api_key,
            :anthropic_req_options,
            :anthropic_model,
            :conversation_lookup
          ] do
        Application.delete_env(:cairnloop, key)
      end
    end)

    :ok
  end

  defp strong_bundle do
    %{
      query: "rotate API key",
      canonical_results: [
        %{
          title: "Rotating an expired token",
          content: "Open Settings > API Keys and click Rotate."
        }
      ],
      assistive_results: [],
      evidence: [%{id: "kb_1", title: "Rotating an expired token", trust_level: :canonical}],
      clarification_attempts: 0,
      grounding_assessment: %{status: :strong, reason: :canonical_hit}
    }
  end

  defp weak_bundle(status) do
    %{
      query: "rotate API key",
      canonical_results: [],
      assistive_results: [],
      evidence: [],
      clarification_attempts: 0,
      grounding_assessment: %{status: status, reason: :insufficient_grounding}
    }
  end

  defp stub_plug(test_pid, status, json) do
    Application.put_env(:cairnloop, :anthropic_req_options,
      plug: fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:anthropic_request, raw})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(status, Jason.encode!(json))
      end
    )
  end

  describe "strong grounding with an API key" do
    test "composes the reply via Claude and carries the strong-grounding snapshot" do
      Application.put_env(:cairnloop, :anthropic_api_key, "sk-test-key")
      Application.put_env(:cairnloop, :anthropic_model, "claude-sonnet-4-6")

      stub_plug(self(), 200, %{
        "content" => [%{"type" => "text", "text" => @model_reply}]
      })

      assert {:ok, proposal} = Anthropic.generate_draft("conv_1", strong_bundle())

      # Model-composed reply surfaced as the draft.
      assert proposal.proposal_type == :reply
      assert proposal.customer_reply == @model_reply
      assert proposal.content == @model_reply
      assert proposal.operator_summary =~ "Model-composed"
      assert proposal.grounding_metadata.grounding_status == :strong
      assert proposal.conversation_id == "conv_1"

      # The request actually went to Claude with our model + grounded source content.
      assert_receive {:anthropic_request, raw}
      assert raw =~ "claude-sonnet-4-6"
      assert raw =~ "Open Settings > API Keys"
      # Prompt context included the loaded conversation transcript.
      assert raw =~ "How do I rotate my API key?"
    end
  end

  describe "fail-closed delegation to ScoriaEngine" do
    test "no API key → deterministic engine (no HTTP call)" do
      Application.delete_env(:cairnloop, :anthropic_api_key)
      # A plug that would flag if called — it must NOT be.
      stub_plug(self(), 200, %{"content" => [%{"type" => "text", "text" => @model_reply}]})

      assert {:ok, proposal} = Anthropic.generate_draft("conv_1", strong_bundle())
      assert {:ok, scoria} = ScoriaEngine.generate_draft("conv_1", strong_bundle())

      assert proposal == scoria
      refute proposal.customer_reply == @model_reply
      refute_receive {:anthropic_request, _}
    end

    test "API error → falls back to the deterministic engine" do
      Application.put_env(:cairnloop, :anthropic_api_key, "sk-test-key")
      stub_plug(self(), 500, %{"error" => "overloaded"})

      assert {:ok, proposal} = Anthropic.generate_draft("conv_1", strong_bundle())
      assert {:ok, scoria} = ScoriaEngine.generate_draft("conv_1", strong_bundle())

      assert proposal == scoria
      # The call was attempted before falling back.
      assert_receive {:anthropic_request, _}
    end

    test "empty model completion → falls back" do
      Application.put_env(:cairnloop, :anthropic_api_key, "sk-test-key")
      stub_plug(self(), 200, %{"content" => [%{"type" => "text", "text" => "   "}]})

      assert {:ok, proposal} = Anthropic.generate_draft("conv_1", strong_bundle())
      assert {:ok, scoria} = ScoriaEngine.generate_draft("conv_1", strong_bundle())
      assert proposal == scoria
    end

    test "clarification grounding → delegates without calling Claude" do
      Application.put_env(:cairnloop, :anthropic_api_key, "sk-test-key")
      stub_plug(self(), 200, %{"content" => [%{"type" => "text", "text" => @model_reply}]})

      assert {:ok, proposal} = Anthropic.generate_draft("conv_1", weak_bundle(:clarification))
      assert proposal.proposal_type == :clarification
      refute_receive {:anthropic_request, _}
    end

    test "escalation grounding → delegates without calling Claude" do
      Application.put_env(:cairnloop, :anthropic_api_key, "sk-test-key")
      stub_plug(self(), 200, %{"content" => [%{"type" => "text", "text" => @model_reply}]})

      assert {:ok, proposal} = Anthropic.generate_draft("conv_1", weak_bundle(:escalation))
      assert proposal.proposal_type == :escalation
      refute_receive {:anthropic_request, _}
    end
  end
end
