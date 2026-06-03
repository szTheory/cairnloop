defmodule Cairnloop.Automation.DraftGenerator.Anthropic do
  @moduledoc """
  Reference `Cairnloop.Automation.DraftGenerator` backed by Anthropic's Claude
  (Messages API). Composes a customer-support reply **only when grounding is strong**,
  using the canonical Knowledge Base evidence the retrieval layer already gathered.

  Fail-closed by construction — it delegates to `Cairnloop.Automation.ScoriaEngine`
  (the deterministic default) in every case where it must not let a model guess:

    * grounding is `:clarification` or `:escalation` (not `:strong`) — ask for the
      missing detail / recommend handoff instead of composing a reply;
    * no API key is configured — degrade gracefully to the deterministic engine
      (mirrors `Cairnloop.Embedder.ExternalApi`'s no-key behaviour);
    * the Anthropic call errors or returns an unparseable body — never crash the
      `DraftWorker`; fall back so a draft still appears for the operator.

  The proposal shape, grounding snapshot, evidence, and human-in-the-loop approval are
  identical to the deterministic engine — only the `:strong`-grounding `customer_reply`
  is model-composed (and still operator-reviewed before any send).

  ## Configuration

      # host config
      config :cairnloop, :draft_generator, Cairnloop.Automation.DraftGenerator.Anthropic

      # runtime.exs — secrets read at boot, never compiled in
      config :cairnloop, :anthropic_api_key, System.fetch_env!("ANTHROPIC_API_KEY")

  Optional knobs (all have sensible defaults):

    * `:anthropic_model` — Claude model id (default `"claude-sonnet-4-6"`)
    * `:anthropic_max_tokens` — reply budget (default `1024`)
    * `:anthropic_req_options` — extra `Req` options merged into the request
      (the seam used by tests to inject a stub `plug:`)
    * `:conversation_lookup` — how to load the thread for prompt context
      (default `&Cairnloop.Chat.get_conversation!/1`; shared with `DraftWorker`)

  The API key is also read from the `ANTHROPIC_API_KEY` env var when not set in config.
  """

  @behaviour Cairnloop.Automation.DraftGenerator

  @fallback Cairnloop.Automation.ScoriaEngine
  @base_url "https://api.anthropic.com"
  @anthropic_version "2023-06-01"
  @default_model "claude-sonnet-4-6"
  @default_max_tokens 1024
  # How many recent conversation messages to include as prompt context.
  @transcript_limit 12

  @impl Cairnloop.Automation.DraftGenerator
  def generate_draft(conversation_id, grounding_bundle) do
    assessment = grounding_bundle.grounding_assessment

    with :strong <- assessment.status,
         key when is_binary(key) and key != "" <- api_key(),
         {:ok, reply_text} <- compose_reply(conversation_id, grounding_bundle, key) do
      {:ok, build_proposal(conversation_id, grounding_bundle, reply_text)}
    else
      # Not strong grounding, no API key, or the model call failed — fall back to the
      # deterministic engine. Fail-closed: never fabricate past the grounding.
      _ -> @fallback.generate_draft(conversation_id, grounding_bundle)
    end
  end

  # --- proposal assembly ----------------------------------------------------

  defp build_proposal(conversation_id, grounding_bundle, reply_text) do
    assessment = grounding_bundle.grounding_assessment
    evidence = Map.get(grounding_bundle, :evidence, [])

    %{
      proposal_type: :reply,
      operator_summary:
        "Model-composed reply grounded in canonical Knowledge Base evidence — review the citations before sending.",
      customer_reply: reply_text,
      content: reply_text,
      evidence: evidence,
      grounding_metadata: %{
        grounding_status: :strong,
        reason: assessment.reason,
        query: grounding_bundle.query
      },
      clarification_attempts: grounding_bundle.clarification_attempts,
      conversation_id: conversation_id
    }
  end

  # --- Anthropic Messages API ----------------------------------------------

  defp compose_reply(conversation_id, grounding_bundle, key) do
    sources = sources_block(grounding_bundle)
    transcript = transcript_block(conversation_id)

    body = %{
      model: model(),
      max_tokens: max_tokens(),
      # System prompt is stable across conversations → cache it (prompt caching).
      system: [
        %{type: "text", text: system_instructions(), cache_control: %{type: "ephemeral"}}
      ],
      messages: [
        %{role: "user", content: user_prompt(sources, transcript)}
      ]
    }

    req =
      Req.new(
        base_url: @base_url,
        headers: [
          {"x-api-key", key},
          {"anthropic-version", @anthropic_version}
        ],
        json: body
      )
      |> Req.merge(req_options())

    case Req.post(req, url: "/v1/messages") do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        extract_text(response_body)

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Anthropic returns a list of content blocks; concatenate the text blocks.
  defp extract_text(%{"content" => blocks}) when is_list(blocks) do
    text =
      blocks
      |> Enum.filter(&(is_map(&1) and &1["type"] == "text"))
      |> Enum.map_join("", &(&1["text"] || ""))
      |> String.trim()

    if text == "", do: {:error, :empty_completion}, else: {:ok, text}
  end

  defp extract_text(_), do: {:error, :unparseable_response}

  # --- prompt construction --------------------------------------------------

  defp system_instructions do
    """
    You are a customer-support reply drafter for a human operator to review.
    Compose a concise, calm, professional reply to the customer using ONLY the
    Knowledge Base sources provided in the user message. Do not invent facts,
    policies, prices, or steps that are not supported by those sources. Prefer the
    customer's own wording for the problem. Do not add a subject line, signature, or
    placeholders like "[Name]". Output only the reply text — no preamble, no quotes,
    no markdown headings.
    """
  end

  defp user_prompt(sources, transcript) do
    [
      "Knowledge Base sources (the only facts you may rely on):",
      "",
      sources,
      "",
      transcript_section(transcript),
      "Draft the next support reply to the customer, grounded only in the sources above."
    ]
    |> Enum.reject(&(&1 == nil))
    |> Enum.join("\n")
  end

  defp transcript_section(""), do: nil

  defp transcript_section(transcript) do
    "Conversation so far:\n\n" <> transcript <> "\n"
  end

  defp sources_block(grounding_bundle) do
    canonical = Map.get(grounding_bundle, :canonical_results, [])

    case canonical do
      [] ->
        "(no canonical sources)"

      results ->
        results
        |> Enum.with_index(1)
        |> Enum.map_join("\n\n", fn {result, idx} ->
          title = Map.get(result, :title) || "Source #{idx}"
          content = result |> Map.get(:content) |> to_string() |> String.slice(0, 1200)
          "[#{idx}] #{title}\n#{content}"
        end)
    end
  end

  defp transcript_block(conversation_id) do
    try do
      conversation = conversation_lookup().(conversation_id)
      messages = conversation_messages(conversation)

      messages
      |> Enum.take(-@transcript_limit)
      |> Enum.map_join("\n", fn message ->
        speaker = message_speaker(Map.get(message, :role))
        content = message |> Map.get(:content) |> to_string()
        "#{speaker}: #{content}"
      end)
    rescue
      _ -> ""
    catch
      _, _ -> ""
    end
  end

  defp conversation_messages(%{messages: messages}) when is_list(messages), do: messages
  defp conversation_messages(_), do: []

  defp message_speaker(:user), do: "Customer"
  defp message_speaker(:agent), do: "Agent"
  defp message_speaker(_), do: "Note"

  # --- config seams ---------------------------------------------------------

  defp api_key do
    Application.get_env(:cairnloop, :anthropic_api_key) || System.get_env("ANTHROPIC_API_KEY")
  end

  defp model, do: Application.get_env(:cairnloop, :anthropic_model, @default_model)

  defp max_tokens,
    do: Application.get_env(:cairnloop, :anthropic_max_tokens, @default_max_tokens)

  defp req_options, do: Application.get_env(:cairnloop, :anthropic_req_options, [])

  defp conversation_lookup do
    Application.get_env(:cairnloop, :conversation_lookup, &Cairnloop.Chat.get_conversation!/1)
  end
end
