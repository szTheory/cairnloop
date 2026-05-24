defmodule Cairnloop.Web.ConversationLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat
  alias Cairnloop.Automation.Draft
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Retrieval.Result
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff
  alias Cairnloop.Web.{ArticleSuggestionPresenter, ReviewTaskPresenter, SearchResultPresenter}
  alias Cairnloop.Web.ToolProposalPresenter

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
    end

    socket =
      socket
      |> assign(form: to_form(%{"content" => ""}), pending_discard_draft_id: nil)
      |> reload_conversation_with_context(id)

    {:ok, socket}
  end

  def handle_info({:draft_created, _draft_id}, socket) do
    {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
  end

  def handle_event("reply", %{"content" => content}, socket) do
    if content != "" do
      case Chat.reply_to_conversation(socket.assigns.conversation.id, content) do
        {:ok, _result} ->
          socket =
            socket
            |> reload_conversation_with_context(socket.assigns.conversation.id)
            |> assign(form: to_form(%{"content" => ""}))

          {:noreply, socket}

        {:error, _failed_operation, _failed_value, _changes_so_far} ->
          {:noreply, put_flash(socket, :error, "Failed to send reply.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("change", %{"content" => content}, socket) do
    {:noreply, assign(socket, form: to_form(%{"content" => content}))}
  end

  def handle_event("approve_draft", %{"draft-id" => draft_id}, socket) do
    case Cairnloop.Automation.approve_draft(String.to_integer(draft_id)) do
      {:ok, _} ->
        {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to approve draft.")}
    end
  end

  def handle_event("edit_draft", %{"draft-id" => draft_id}, socket) do
    draft_id = String.to_integer(draft_id)
    draft = Enum.find(socket.assigns.conversation.drafts, &(&1.id == draft_id))

    case Cairnloop.Automation.mark_draft_edited(draft_id) do
      {:ok, _} ->
        socket =
          socket
          |> reload_conversation_with_context(socket.assigns.conversation.id)
          |> assign(form: to_form(%{"content" => Draft.reply_content(draft)}))

        {:noreply, socket}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to edit draft.")}
    end
  end

  def handle_event("discard_draft", %{"draft-id" => draft_id}, socket) do
    {:noreply, assign(socket, pending_discard_draft_id: String.to_integer(draft_id))}
  end

  def handle_event("cancel_discard_draft", _params, socket) do
    {:noreply, assign(socket, pending_discard_draft_id: nil)}
  end

  def handle_event("confirm_discard_draft", %{"draft-id" => draft_id}, socket) do
    case Cairnloop.Automation.discard_draft(String.to_integer(draft_id)) do
      {:ok, _} ->
        socket =
          socket
          |> assign(pending_discard_draft_id: nil)
          |> reload_conversation_with_context(socket.assigns.conversation.id)

        {:noreply, socket}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to discard draft.")}
    end
  end

  def handle_event("start_quick_fix", _params, socket) do
    conversation = socket.assigns.conversation
    opts = quick_fix_scope_opts(conversation)

    case knowledge_automation().create_or_reuse_conversation_quick_fix(
           quick_fix_request_attrs(conversation),
           opts
         ) do
      {:ok, %{suggestion: suggestion, review_task: review_task}} ->
        card = quick_fix_card_state(suggestion, review_task)
        socket = assign(socket, :quick_fix_card, card)

        case card.status do
          status when status in [:ready, :shell_created] ->
            {:noreply, push_navigate(socket, to: review_task_path(review_task.id))}

          _ ->
            {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Quick fix could not prepare a reviewable suggestion.")}
    end
  end

  def handle_event("open_review_task", _params, socket) do
    case socket.assigns.quick_fix_card[:review_task_id] do
      nil ->
        {:noreply, put_flash(socket, :error, "No review task is available for this quick fix yet.")}

      review_task_id ->
        {:noreply, push_navigate(socket, to: review_task_path(review_task_id))}
    end
  end

  def handle_event("open_manual_draft", _params, socket) do
    case socket.assigns.quick_fix_card[:suggestion_id] do
      nil ->
        {:noreply, put_flash(socket, :error, "No manual draft is available for this quick fix yet.")}

      suggestion_id ->
        case knowledge_automation().create_or_reuse_authoring_article_for_suggestion(
               suggestion_id,
               quick_fix_scope_opts(socket.assigns.conversation)
             ) do
          {:ok, article_id} ->
            return_path = "/#{socket.assigns.conversation.id}"
            return_to = URI.encode_www_form(return_path)
            review_task_param = manual_review_task_param(socket.assigns.quick_fix_card[:review_task_id])
            handoff_token =
              EditorHandoff.sign(
                suggestion_id,
                article_id,
                socket.assigns.quick_fix_card[:review_task_id],
                return_path
              )

            {:noreply,
             push_navigate(
               socket,
               to:
                 "/knowledge-base/#{article_id}/edit?suggestion_id=#{suggestion_id}" <>
                   review_task_param <> "&return_to=#{return_to}&handoff=#{URI.encode_www_form(handoff_token)}"
             )}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Manual draft could not be opened right now.")}
        end
    end
  end

  def handle_event("execute_tool", %{"tool" => tool_ref} = params, socket) do
    actor_id = socket.assigns.conversation.host_user_id
    context = socket.assigns.host_context
    # Merge form params into context so Governance.validate/3 can call changeset/2 (D-27)
    context = Map.put(context, :tool_params, params["tool_params"] || %{})
    # D-07: thread server-trusted conversation_id into propose context (NOT from request params)
    context = Map.put(context, :conversation_id, socket.assigns.conversation.id)

    case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
      {:ok, proposal} ->
        {:noreply, put_flash(socket, :info, "Proposed — pending review. (##{proposal.id})")}

      {:blocked, outcome, reason} ->
        {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}

      {:error, _changeset} ->
        # Fail closed: never surface a raw changeset to the operator (CR-01)
        {:noreply,
         put_flash(
           socket,
           :error,
           "This action could not be recorded right now. Please try again."
         )}
    end
  end

  # Phase 15: Approve/Reject/Defer handlers — persist + (approve) enqueue via facade; never inline execute (APRV-01).
  # Reflects outcomes via existing thin-notification → reload_conversation_with_context path.
  # Plain-assign, no streams (P14 D-02). Reason enforced by facade for reject/defer (FLOW-03).

  def handle_event("approve_action", %{"approval-id" => id}, socket) do
    actor_id = socket.assigns.conversation.host_user_id

    case Cairnloop.Governance.approve(String.to_integer(id), actor_id, []) do
      {:ok, _approval} ->
        {:noreply,
         socket
         |> put_flash(:info, "Action approved.")
         |> reload_conversation_with_context(socket.assigns.conversation.id)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Approval record not found.")}

      {:error, :not_pending} ->
        {:noreply, put_flash(socket, :error, "This action has already been decided.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Approval could not be recorded. Please try again.")}
    end
  end

  def handle_event("reject_action", %{"approval-id" => id, "reason" => reason}, socket) do
    actor_id = socket.assigns.conversation.host_user_id

    case Cairnloop.Governance.reject(String.to_integer(id), actor_id, reason: reason) do
      {:ok, _approval} ->
        {:noreply,
         socket
         |> put_flash(:info, "Action rejected.")
         |> reload_conversation_with_context(socket.assigns.conversation.id)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Approval record not found.")}

      {:error, :not_pending} ->
        {:noreply, put_flash(socket, :error, "This action has already been decided.")}

      {:error, _} ->
        # FLOW-03: missing reason or invalid changeset — calm error (never raw changeset to operator)
        {:noreply, put_flash(socket, :error, "A reason is required to reject this action.")}
    end
  end

  def handle_event("defer_action", %{"approval-id" => id, "reason" => reason}, socket) do
    actor_id = socket.assigns.conversation.host_user_id

    case Cairnloop.Governance.defer(String.to_integer(id), actor_id, reason: reason) do
      {:ok, _approval} ->
        {:noreply,
         socket
         |> put_flash(:info, "Action deferred.")
         |> reload_conversation_with_context(socket.assigns.conversation.id)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Approval record not found.")}

      {:error, :not_pending} ->
        {:noreply, put_flash(socket, :error, "This action has already been decided.")}

      {:error, _} ->
        # FLOW-03: missing reason or invalid changeset — calm error
        {:noreply, put_flash(socket, :error, "A reason is required to defer this action.")}
    end
  end

  defp failure_reason_message(:unsupported, _reason), do: "Unknown tool — proposal rejected."
  defp failure_reason_message(:needs_input, _cs), do: "Invalid tool parameters."

  # D-14: humanize via ToolProposalPresenter.reason_label/1 — no raw Elixir terms to operator
  defp failure_reason_message(:scope_invalid, reason),
    do: "Tool not available in this context: #{ToolProposalPresenter.reason_label(reason)}."

  defp failure_reason_message(:policy_denied, reason),
    do: "Tool call not permitted: #{ToolProposalPresenter.reason_label(reason)}."

  defp failure_reason_message(outcome, reason),
    do: "Tool proposal blocked (#{outcome}): #{ToolProposalPresenter.reason_label(reason)}."

  defp reload_conversation_with_context(socket, conversation_id) do
    conversation = Chat.get_conversation!(conversation_id)
    {context, context_error} = load_host_context(conversation)
    quick_fix_card = load_quick_fix_card(conversation)
    # D-09: load governed_actions via the narrow facade (never direct schema query from web layer)
    governed_actions = Cairnloop.Governance.list_proposals_for_conversation(conversation_id)

    assign(socket,
      conversation: conversation,
      host_context: context,
      context_error: context_error,
      quick_fix_card: quick_fix_card,
      governed_actions: governed_actions
    )
  end

  defp load_host_context(conversation) do
    provider =
      Application.get_env(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider)

    if conversation.host_user_id do
      case provider.get_context(conversation.host_user_id, []) do
        {:ok, map} -> {map, nil}
        {:error, reason} -> {%{}, reason}
      end
    else
      {%{}, nil}
    end
  end

  defp load_quick_fix_card(conversation) do
    opts =
      [tenant_scope: :host_user_scoped, host_user_id: conversation.host_user_id]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    case knowledge_automation().get_conversation_quick_fix(conversation.id, opts) do
      {:ok, %{suggestion: suggestion, review_task: review_task}} ->
        quick_fix_card_state(suggestion, review_task)

      _ ->
        idle_quick_fix_card(conversation)
    end
  end

  def render(assigns) do
    assigns = assign(assigns, :quick_fix_card, normalize_quick_fix_card(assigns))
    # Default governed_actions to [] when not present (e.g. direct render_component tests)
    assigns = Map.put_new(assigns, :governed_actions, [])

    ~H"""
    <.live_component
      module={Cairnloop.Web.SearchModalComponent}
      id="search-modal"
      host_surface="conversation"
      host_user_id={@conversation.host_user_id}
      current_path={"/#{@conversation.id}"}
      preserve_reply_form={true}
    />
    <style>
      .conversation-layout {
        display: flex;
        flex-direction: column;
        gap: 32px;
      }
      @media (min-width: 1024px) {
        .conversation-layout {
          flex-direction: row;
        }
        .message-timeline {
          flex: 1;
        }
        .evidence-rail {
          width: 352px;
          flex-shrink: 0;
        }
      }
      .evidence-rail {
        display: flex;
        flex-direction: column;
        gap: 24px;
      }
      .rail-card {
        padding: 24px;
        background: #fbf7ee;
        border: 1px solid #d8ccb8;
        border-radius: 8px;
      }
      .quick-fix-card {
        background: #fbf7ee;
        border-color: #c9b89c;
      }
      .quick-fix-eyebrow,
      .quick-fix-layer-label,
      .quick-fix-status-label {
        font-size: 0.875rem;
        font-weight: 600;
      }
      .quick-fix-eyebrow {
        text-transform: uppercase;
        letter-spacing: 0.04em;
        color: #7c5430;
      }
      .quick-fix-summary {
        margin: 8px 0 16px;
        color: #3b2d1f;
      }
      .quick-fix-layers,
      .quick-fix-status-rail {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      .quick-fix-layer,
      .quick-fix-status-chip {
        padding: 12px;
        border-radius: 8px;
        background: #f5efe3;
        border: 1px solid #ddcfba;
      }
      .quick-fix-layer-meta {
        color: #64513c;
        margin-left: 8px;
      }
      .quick-fix-layer-summary {
        margin-top: 4px;
        color: #4c4033;
      }
      .quick-fix-reason {
        margin: 16px 0;
        padding: 12px;
        border-radius: 8px;
        background: #f4e6d4;
        border: 1px solid #c38f57;
        color: #5d3b16;
      }
      .quick-fix-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        align-items: center;
        margin: 16px 0;
      }
      .quick-fix-actions button,
      .quick-fix-actions a {
        min-height: 44px;
      }
      .quick-fix-actions button {
        padding: 10px 16px;
        border-radius: 8px;
        border: 1px solid #a94f30;
        background: #a94f30;
        color: #fffdf8;
      }
      .quick-fix-actions a {
        display: inline-flex;
        align-items: center;
        color: #7d432d;
      }
      .quick-fix-status-chip.current {
        border-color: #a94f30;
        background: #f4e6d4;
      }
      .context-field {
        margin-bottom: 16px;
      }
      .context-field:last-child {
        margin-bottom: 0;
      }
      .draft-actions button {
        margin-right: 8px;
        margin-top: 8px;
      }
      .discard-confirm {
        margin-top: 16px;
        padding: 12px;
        background: #fee2e2;
        border-radius: 4px;
      }
      /* governed-action-card — Wave 2 */
      .governed-action-card {
        background: #fbf7ee;
        border-color: #c9b89c;
      }
      .governed-action-eyebrow {
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: #7c5430;
        margin-bottom: 4px;
      }
      .governed-action-headline {
        margin: 0 0 12px;
        font-size: 1rem;
        line-height: 1.4;
        color: #2f241d;
      }
      .governed-action-status-row {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        align-items: center;
        margin-bottom: 12px;
      }
      .governed-action-chip {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        padding: 3px 10px;
        border-radius: 12px;
        font-size: 0.8rem;
        font-weight: 600;
        border: 1px solid currentColor;
      }
      .governed-action-chip-info {
        color: #1d6a8c;
        background: #e8f4f9;
      }
      .governed-action-chip-warning {
        color: #7a5c00;
        background: #fef9e5;
      }
      .governed-action-chip-danger {
        color: #8b1a1a;
        background: #fdecea;
      }
      .governed-action-chip-status {
        color: var(--cl-primary, #A94F30);
        background: #f4e6d4;
        border-color: #c38f57;
      }
      .governed-action-meta-row {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        font-size: 0.85rem;
        color: #64513c;
        margin-bottom: 8px;
      }
      .governed-action-outlook {
        font-size: 0.85rem;
        color: #4c4033;
        margin-bottom: 12px;
        font-style: italic;
      }
      .governed-action-section {
        margin-top: 16px;
        padding-top: 12px;
        border-top: 1px solid #e8e0d0;
      }
      .governed-action-section-label {
        font-size: 0.8rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.04em;
        color: #7c5430;
        margin-bottom: 8px;
      }
      .governed-action-event-item {
        padding: 8px 0;
        border-bottom: 1px solid #ede7d6;
        font-size: 0.85rem;
      }
      .governed-action-event-item:last-child {
        border-bottom: none;
      }
      .governed-action-event-time {
        font-size: 0.75rem;
        color: #8b7355;
        margin-left: 8px;
      }
      .governed-action-trace {
        font-family: monospace;
        font-size: 0.75rem;
        color: #8b7355;
        background: #f5efe3;
        padding: 8px;
        border-radius: 4px;
        word-break: break-all;
      }
      .governed-action-trace dt {
        font-weight: 600;
        display: inline;
      }
      .governed-action-trace dd {
        display: inline;
        margin: 0 0 0 4px;
      }
      .governed-action-footer {
        margin-top: 16px;
        padding-top: 12px;
        border-top: 1px solid #e8e0d0;
        min-height: 8px;
        /* Phase-15 affordance slot — empty in Phase 14 (D-05) */
      }
      .governed-action-scope-warning {
        margin-top: 8px;
        padding: 8px 12px;
        background: #fef9e5;
        border: 1px solid #c38f57;
        border-radius: 6px;
        font-size: 0.85rem;
        color: #5d3b16;
      }
      /* governed-actions rail section — Wave 3 */
      .governed-actions-rail {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }
      .governed-actions-rail-header {
        margin-bottom: 4px;
      }
      .governed-actions-rail-eyebrow {
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--cl-primary, #A94F30);
      }
      .governed-actions-empty {
        font-size: 0.9rem;
        color: #7c5430;
        margin: 0;
        font-style: italic;
      }
    </style>
    <div class="cairnloop-conversation">
      <.link navigate="/">Back to Inbox</.link>
      <h2><%= @conversation.subject || "No Subject" %></h2>
      
      <div class="conversation-layout">
        <div class="message-timeline">
          <div class="messages">
            <%= for msg <- @conversation.messages do %>
              <div class={"message role-#{msg.role}"}>
                <strong><%= msg.role %>:</strong>
                <p><%= msg.content %></p>
              </div>
            <% end %>
          </div>

          <div class="reply-form" style="margin-top: 24px;">
            <.form for={@form} phx-submit="reply" phx-change="change">
              <textarea name="content" placeholder="Type a reply..." style="width: 100%; min-height: 100px;"><%= @form.params["content"] %></textarea>
              <button type="submit">Send Reply</button>
            </.form>
          </div>
        </div>

        <div class="evidence-rail">
          <.context_pane context={@host_context} error={@context_error} actor_id={@conversation.host_user_id} socket={@socket} />
          <.quick_fix_card card={@quick_fix_card} />

          <%= if Ecto.assoc_loaded?(@conversation.drafts) and length(@conversation.drafts) > 0 do %>
            <%= for draft <- @conversation.drafts do %>
              <.draft_audit_card
                draft={draft}
                pending_discard_id={@pending_discard_draft_id}
              />
            <% end %>
          <% end %>

          <%!-- Governed actions rail section (D-01: right rail, not center timeline; D-02: plain assign, no streams) --%>
          <section class="rail-card governed-actions-rail" aria-label="Governed actions">
            <div class="governed-actions-rail-header">
              <span class="governed-actions-rail-eyebrow">Governed actions</span>
            </div>
            <%= if @governed_actions == [] do %>
              <p class="governed-actions-empty">No governed actions yet.</p>
            <% else %>
              <%= for proposal <- @governed_actions do %>
                <.governed_action_card proposal={proposal} />
              <% end %>
            <% end %>
          </section>
        </div>
      </div>
    </div>
    """
  end

  def context_pane(assigns) do
    assigns =
      assign(
        assigns,
        :available_tools,
        Cairnloop.ToolRegistry.get_available_tools(assigns.actor_id, assigns.context)
      )

    ~H"""
    <div class={["rail-card host-context", @error && "error"]}>
      <h3>Customer Context</h3>
      <%= if @error do %>
        <p>Customer context is unavailable right now. Continue handling the conversation, then reload to try again.</p>
      <% else %>
        <%= if map_size(@context) == 0 do %>
          <h4>No customer context yet</h4>
          <p>This conversation has no host context to show. Continue with the thread, or reload after host data becomes available.</p>
        <% else %>
          <div class="context-sections">
            <%= for {key, value} <- normalize_context_sections(@context) do %>
              <.context_section label={key} value={value} />
            <% end %>
          </div>
          
          <%= if length(@available_tools) > 0 do %>
            <div class="actions-section" style="margin-top: 24px; border-top: 1px solid #e5e7eb; padding-top: 16px;">
              <h3>Actions</h3>
              <div class="tools-list" style="display: flex; flex-direction: column; gap: 16px;">
                <%= for tool <- @available_tools do %>
                  <.tool_renderer tool={tool} actor_id={@actor_id} context={@context} socket={@socket} />
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :card, :map, required: true

  def quick_fix_card(assigns) do
    ~H"""
    <section class="rail-card quick-fix-card" aria-live="polite">
      <div class="quick-fix-eyebrow">KB maintenance</div>
      <h3><%= ReviewTaskPresenter.thread_status_label(@card.status) %></h3>
      <p class="quick-fix-summary"><%= @card.summary %></p>

      <div class="quick-fix-layers">
        <%= for layer <- @card.layers do %>
          <div class="quick-fix-layer">
            <div>
              <span class="quick-fix-layer-label"><%= layer.label %></span>
              <span class="quick-fix-layer-meta"><%= layer.trust %></span>
            </div>
            <div class="quick-fix-layer-summary"><%= layer.summary %></div>
          </div>
        <% end %>
      </div>

      <%= if @card.reason do %>
        <div class="quick-fix-reason">
          <strong>Reason:</strong> <%= @card.reason %>
        </div>
      <% end %>

      <div class="quick-fix-actions">
        <button type="button" phx-click={@card.primary_action.event}>
          <%= @card.primary_action.label %>
        </button>

        <%= if @card.secondary_action do %>
          <a href={@card.secondary_action.to}><%= @card.secondary_action.label %></a>
        <% end %>
      </div>

      <div class="quick-fix-status-rail">
        <%= for chip <- @card.status_rail do %>
          <div class={["quick-fix-status-chip", chip.current && "current"]}>
            <div class="quick-fix-status-label"><%= chip.label %></div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  def tool_renderer(assigns) do
    custom_ui = assigns.tool.custom_ui()

    if custom_ui do
      assigns = assign(assigns, :custom_ui, custom_ui)

      ~H"""
      <div class="tool-custom-ui" style="padding: 12px; border: 1px solid #d1d5db; border-radius: 6px; background: #fff;">
        <%= live_render(@socket, @custom_ui, id: "tool-#{inspect(@tool)}", session: %{"actor_id" => @actor_id, "context" => @context}) %>
      </div>
      """
    else
      schema_fields = assigns.tool.__schema__(:fields) -- [:id]

      assigns = assign(assigns, :schema_fields, schema_fields)

      if length(schema_fields) == 0 do
        ~H"""
        <button phx-click="execute_tool" phx-value-tool={inspect(@tool)} style="width: 100%; text-align: left; padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 6px; background: #fff; cursor: pointer;">
          <strong><%= humanize_context_label(last_module_part(@tool)) %></strong>
        </button>
        """
      else
        params = Enum.into(schema_fields, %{}, fn f -> {to_string(f), ""} end)
        assigns = assign(assigns, :form, to_form(params, as: :tool_params))

        ~H"""
        <div class="tool-form" style="padding: 12px; border: 1px solid #d1d5db; border-radius: 6px; background: #fff;">
          <strong><%= humanize_context_label(last_module_part(@tool)) %></strong>
          <.form for={@form} phx-submit="execute_tool" style="margin-top: 8px; display: flex; flex-direction: column; gap: 8px;">
            <input type="hidden" name="tool" value={inspect(@tool)} />
            <%= for field <- @schema_fields do %>
              <div>
                <label style="display: block; font-size: 0.85em; margin-bottom: 4px; color: #4b5563;"><%= humanize_context_label(field) %></label>
                <input type="text" name={@form[field].name} value={@form[field].value} style="width: 100%; padding: 6px; border: 1px solid #d1d5db; border-radius: 4px;" />
              </div>
            <% end %>
            <button type="submit" style="padding: 6px 12px; background: var(--cl-primary, #A94F30); color: white; border: none; border-radius: 4px; cursor: pointer; align-self: flex-start;">Propose</button>
          </.form>
        </div>
        """
      end
    end
  end

  defp last_module_part(module) do
    module |> Module.split() |> List.last()
  end

  def context_section(assigns) do
    ~H"""
    <div class="context-section" style="margin-bottom: 16px;">
      <h4 style="margin-bottom: 8px; font-size: 0.9em; text-transform: uppercase; color: #6b7280;"><%= humanize_context_label(@label) %></h4>
      <%= if is_map(@value) do %>
        <div class="context-subsection" style="padding-left: 12px; border-left: 2px solid #e5e7eb;">
          <%= for {k, v} <- normalize_context_sections(@value) do %>
            <.context_field label={k} value={v} />
          <% end %>
        </div>
      <% else %>
         <.context_field label={@label} value={@value} hide_label={true} />
      <% end %>
    </div>
    """
  end

  def context_field(assigns) do
    assigns = assign_new(assigns, :hide_label, fn -> false end)

    ~H"""
    <div class="context-field">
      <%= if not @hide_label do %>
        <strong><%= humanize_context_label(@label) %>:</strong>
      <% end %>
      <span><%= normalize_context_value(@value) %></span>
    </div>
    """
  end

  def draft_audit_card(assigns) do
    assigns =
      assigns
      |> assign(:draft_reply, Draft.reply_content(assigns.draft))
      |> assign(:operator_summary, draft_operator_summary(assigns.draft))
      |> assign(:proposal_state_label, proposal_state_label(assigns.draft))
      |> assign(:grounding_reason_label, grounding_reason_label(assigns.draft))
      |> assign(:grounding_reason_copy, grounding_reason_copy(assigns.draft))
      |> assign(:evidence, draft_evidence(assigns.draft))

    ~H"""
    <div class="rail-card draft">
      <h3>AI Draft / Audit</h3>
      <p><strong>Proposal state:</strong> <%= @proposal_state_label %></p>
      <p><em>Status: <%= @draft.status %></em></p>

      <div class="context-field">
        <strong>Operator summary:</strong>
        <p><%= @operator_summary %></p>
      </div>

      <%= if @grounding_reason_label do %>
        <div class="context-field">
          <strong>Grounding note:</strong>
          <p><strong><%= @grounding_reason_label %></strong></p>
          <p><%= @grounding_reason_copy %></p>
        </div>
      <% end %>

      <div class="context-field">
        <strong>Customer reply:</strong>
        <p><%= @draft_reply %></p>
      </div>

      <div class="context-field">
        <strong>Supporting evidence</strong>
        <%= if @evidence == [] do %>
          <p>No supporting evidence captured for this proposal.</p>
        <% else %>
          <div>
            <%= for evidence <- @evidence do %>
              <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #e5e7eb;">
                <p>
                  <strong><%= SearchResultPresenter.source_label(evidence) %></strong>
                  ·
                  <strong><%= SearchResultPresenter.trust_label(evidence) %></strong>
                </p>
                <p><strong><%= SearchResultPresenter.title(evidence) %></strong></p>
                <p><%= SearchResultPresenter.row_snippet(evidence) %></p>
                <p><em><%= SearchResultPresenter.recency_label(evidence) %></em></p>
                <%= if path = SearchResultPresenter.open_path(evidence) do %>
                  <p>
                    <.link navigate={path}><%= SearchResultPresenter.open_action_label(evidence) %></.link>
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @draft.status in [:pending, :edited] do %>
        <div class="draft-actions">
          <button phx-click="approve_draft" phx-value-draft-id={@draft.id}>Approve & Send</button>
          <button phx-click="edit_draft" phx-value-draft-id={@draft.id}>Apply to Composer</button>
          <button phx-click="discard_draft" phx-value-draft-id={@draft.id}>Discard</button>
        </div>
      <% end %>

      <%= if @pending_discard_id == @draft.id do %>
        <div class="discard-confirm">
          <p>Discard draft: Remove this draft from the rail? This action is recorded and cannot be undone.</p>
          <button phx-click="confirm_discard_draft" phx-value-draft-id={@draft.id}>Confirm</button>
          <button phx-click="cancel_discard_draft">Cancel</button>
        </div>
      <% end %>
    </div>
    """
  end

  attr :proposal, :map, required: true

  def governed_action_card(assigns) do
    proposal = assigns.proposal

    # Precompute presenter values before the ~H block (in-repo pattern — keep template declarative)
    status_label = ToolProposalPresenter.status_label(proposal)
    status_group = ToolProposalPresenter.status_group(proposal.status)
    risk_tier_label = ToolProposalPresenter.risk_tier_label(proposal.risk_tier)
    risk_tier_tone = ToolProposalPresenter.risk_tier_tone(proposal.risk_tier)
    approval_mode_label = ToolProposalPresenter.approval_mode_label(proposal.approval_mode)
    input_rows = ToolProposalPresenter.input_rows(proposal.input_snapshot)
    scope_summary = ToolProposalPresenter.scope_summary(proposal.scope_snapshot)
    policy_explanation = ToolProposalPresenter.policy_explanation(proposal.policy_snapshot)
    trace = ToolProposalPresenter.trace_metadata(proposal)
    block_reason = ToolProposalPresenter.block_reason_copy(proposal)

    # Resolve active approval (D15-17): read from preloaded :approval association when loaded,
    # otherwise fall back to facade (never inline re-read; goes through the narrow facade).
    active_approval =
      cond do
        Ecto.assoc_loaded?(proposal.approval) and proposal.approval != nil ->
          proposal.approval

        Ecto.assoc_loaded?(proposal.approval) ->
          # Loaded but nil — no active approval
          nil

        true ->
          # Not preloaded — resolve via facade (D15-17)
          Cairnloop.Governance.get_active_approval(proposal.id)
      end

    # Approval outlook: use real present-tense copy when approval exists (D15-16),
    # fall back to future-tense honesty seam when no active approval.
    approval_outlook =
      if active_approval do
        ToolProposalPresenter.approval_outlook_for_approval(active_approval)
      else
        ToolProposalPresenter.approval_outlook(proposal.approval_mode)
      end

    # Events guard: D-24 — empty or not-loaded → "No history yet"
    events_loaded =
      Ecto.assoc_loaded?(proposal.events) and is_list(proposal.events) and proposal.events != []

    events =
      if events_loaded do
        proposal.events
        |> Enum.map(fn ev ->
          %{
            line: ToolProposalPresenter.history_line(ev),
            timestamp: ToolProposalPresenter.event_timestamp_label(ev.inserted_at),
            reason: ToolProposalPresenter.reason_label(Map.get(ev, :reason)),
            metadata: ev.metadata
          }
        end)
      else
        []
      end

    # Risk tone maps to CSS modifier class — brand §7.5 / D-13
    # Tone atom (:info/:warning/:danger) → chip class. Never color-alone.
    risk_chip_class =
      case risk_tier_tone do
        :info -> "governed-action-chip governed-action-chip-info"
        :warning -> "governed-action-chip governed-action-chip-warning"
        :danger -> "governed-action-chip governed-action-chip-danger"
        _ -> "governed-action-chip governed-action-chip-info"
      end

    # Status chip uses brand primary token for visual emphasis (D-13 — separate axis from risk)
    status_chip_class = "governed-action-chip governed-action-chip-status"

    # Headline: read snapshotted prose columns (D15-14).
    # Phase 15+ rows: snapshotted title/rendered_consequence.
    # Pre-Phase-15 rows (NULL snapshot columns): structured-summary card fallback (P14 D-17)
    # using the humanized tool_ref display name — no live registry call.
    {eyebrow, headline} =
      cond do
        # Phase 15+ rows: prefer snapshotted title (D15-14)
        is_binary(proposal.title) and proposal.title != "" ->
          {"Governed action", proposal.title}

        # Phase 15+ rows with consequence prose
        is_binary(proposal.rendered_consequence) and proposal.rendered_consequence != "" ->
          {"Governed action", proposal.rendered_consequence}

        # Pre-Phase-15 rows: structured-summary card fallback (P14 D-17)
        true ->
          tool_display =
            case proposal.tool_ref do
              ref when is_binary(ref) ->
                ref |> String.split(".") |> List.last() |> humanize_context_label()
              _ ->
                "Governed action"
            end
          {"Governed action", tool_display}
      end

    assigns =
      assigns
      |> assign(:status_label, status_label)
      |> assign(:status_group, status_group)
      |> assign(:risk_tier_label, risk_tier_label)
      |> assign(:approval_mode_label, approval_mode_label)
      |> assign(:approval_outlook, approval_outlook)
      |> assign(:active_approval, active_approval)
      |> assign(:input_rows, input_rows)
      |> assign(:scope_summary, scope_summary)
      |> assign(:policy_explanation, policy_explanation)
      |> assign(:trace, trace)
      |> assign(:block_reason, block_reason)
      |> assign(:events_loaded, events_loaded)
      |> assign(:events, events)
      |> assign(:risk_chip_class, risk_chip_class)
      |> assign(:status_chip_class, status_chip_class)
      |> assign(:eyebrow, eyebrow)
      |> assign(:headline, headline)

    ~H"""
    <section class="rail-card governed-action-card" aria-label="Governed action proposal">
      <%!-- Eyebrow + headline (snapshotted title/consequence — D15-14; structured fallback for pre-Phase-15 rows) --%>
      <div class="governed-action-eyebrow"><%= @eyebrow %></div>
      <h3 class="governed-action-headline"><%= @headline %></h3>

      <%!-- Status chip: color tone + TEXT label — never color-alone (brand §7.5 / D-13) --%>
      <div class="governed-action-status-row">
        <span class={@status_chip_class}>
          <%= @status_label %>
        </span>
      </div>

      <%!-- Meta line: risk tier + approval mode as SEPARATE axes from the status chip (D-13) --%>
      <div class="governed-action-meta-row">
        <span class={@risk_chip_class}>
          Risk: <%= @risk_tier_label %>
        </span>
        <span>
          Approval: <%= @approval_mode_label %>
        </span>
      </div>

      <%!-- Approval outlook sub-line — only when non-nil; future-tense, non-actionable (D-12) --%>
      <%= if @approval_outlook do %>
        <p class="governed-action-outlook"><%= @approval_outlook %></p>
      <% end %>

      <%!-- Block reason copy (scope_invalid / policy_denied only) --%>
      <%= if @block_reason do %>
        <p class="governed-action-scope-warning"><%= @block_reason %></p>
      <% end %>

      <%!-- Input snapshot: humanized rows via input_rows/1 (D-22 masking choke point) --%>
      <%= if @input_rows != [] do %>
        <div class="governed-action-section">
          <div class="governed-action-section-label">Inputs</div>
          <%= for {label, value} <- @input_rows do %>
            <.context_field label={label} value={value} hide_label={false} />
          <% end %>
        </div>
        <%!-- Raw input_snapshot ONLY behind an explicit expander (D-22) --%>
        <details style="margin-top: 8px;">
          <summary style="font-size: 0.8rem; color: #8b7355; cursor: pointer;">Raw input snapshot</summary>
          <pre class="governed-action-trace" style="margin-top: 8px; white-space: pre-wrap;"><%= inspect(@proposal.input_snapshot, pretty: true) %></pre>
        </details>
      <% end %>

      <%!-- Event mini-timeline (D-24 guarded) --%>
      <div class="governed-action-section">
        <div class="governed-action-section-label">History</div>
        <%= if @events_loaded do %>
          <%= for event <- @events do %>
            <div class="governed-action-event-item">
              <span><%= event.line %></span>
              <span class="governed-action-event-time"><%= event.timestamp %></span>
              <%!-- Per-event detail (reason + metadata) behind expander (D-22) --%>
              <%!-- WR-04: guard on emptiness — empty %{} metadata must not open the expander --%>
              <%= if event.reason || (is_map(event.metadata) and map_size(event.metadata) > 0) do %>
                <details style="margin-top: 4px;">
                  <summary style="font-size: 0.75rem; color: #8b7355; cursor: pointer;">Details</summary>
                  <div style="margin-top: 4px; font-size: 0.8rem; color: #4c4033;">
                    <%= if event.reason do %>
                      <p><strong>Reason:</strong> <%= event.reason %></p>
                    <% end %>
                    <%= if is_map(event.metadata) and map_size(event.metadata) > 0 do %>
                      <pre class="governed-action-trace" style="margin-top: 4px; white-space: pre-wrap;"><%= inspect(event.metadata, pretty: true) %></pre>
                    <% end %>
                  </div>
                </details>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <p style="font-size: 0.85rem; color: #8b7355;">No history yet.</p>
        <% end %>
      </div>

      <%!-- Scope snapshot --%>
      <div class="governed-action-section">
        <div class="governed-action-section-label">Scope</div>
        <p style="font-size: 0.85rem; color: #4c4033;"><%= @scope_summary %></p>
      </div>

      <%!-- Policy snapshot: calm sentence (D-22 / D-14); raw policy map behind expander --%>
      <div class="governed-action-section">
        <div class="governed-action-section-label">Policy</div>
        <p style="font-size: 0.85rem; color: #4c4033;"><%= @policy_explanation %></p>
        <%= if @proposal.policy_snapshot do %>
          <details style="margin-top: 4px;">
            <summary style="font-size: 0.8rem; color: #8b7355; cursor: pointer;">Raw policy snapshot</summary>
            <pre class="governed-action-trace" style="margin-top: 8px; white-space: pre-wrap;"><%= inspect(@proposal.policy_snapshot, pretty: true) %></pre>
          </details>
        <% end %>
      </div>

      <%!-- Trace metadata — de-emphasized mono, copyable (proposal id, tool_ref, version, idempotency key) --%>
      <div class="governed-action-section">
        <dl class="governed-action-trace">
          <div><dt>Proposal:</dt><dd>#<%= @trace.proposal_id %></dd></div>
          <div><dt>Tool:</dt><dd><%= @trace.tool_ref %></dd></div>
          <div><dt>Version:</dt><dd><%= @trace.tool_version %></dd></div>
          <div><dt>Idempotency key:</dt><dd><%= @trace.idempotency_key %></dd></div>
        </dl>
      </div>

      <%!-- Footer action slot: Approve / Reject / Defer affordances when :pending approval exists.
           Status conveyed by text AND color — never color-alone (brand §7.5).
           Brand token var(--cl-primary, #A94F30) for primary affordance color (§2.2/§7). --%>
      <div class="governed-action-footer">
        <%= if @active_approval && @active_approval.status == :pending do %>
          <div style="display: flex; flex-direction: column; gap: 12px;">
            <div style="font-size: 0.85rem; color: #4c4033; font-weight: 600;">Approval required</div>
            <%!-- Approve: primary affordance — color + text (brand §7.5) --%>
            <div style="display: flex; flex-wrap: wrap; gap: 8px; align-items: flex-start;">
              <button
                phx-click="approve_action"
                phx-value-approval-id={@active_approval.id}
                style="padding: 8px 16px; border-radius: 6px; border: 1px solid var(--cl-primary, #A94F30); background: var(--cl-primary, #A94F30); color: #fffdf8; font-size: 0.85rem; font-weight: 600; min-height: 36px; cursor: pointer;"
              >
                Approve
              </button>
              <%!-- Reject: with inline reason capture --%>
              <form phx-submit="reject_action" style="display: flex; flex-direction: column; gap: 6px;">
                <input type="hidden" name="approval-id" value={@active_approval.id} />
                <textarea
                  name="reason"
                  placeholder="Reason for rejection (required)"
                  rows="2"
                  style="padding: 6px 8px; border: 1px solid #c38f57; border-radius: 4px; font-size: 0.8rem; width: 100%; resize: vertical;"
                ></textarea>
                <button
                  type="submit"
                  style="padding: 6px 12px; border-radius: 6px; border: 1px solid #8b1a1a; background: #fdecea; color: #8b1a1a; font-size: 0.8rem; font-weight: 600; min-height: 32px; cursor: pointer; align-self: flex-start;"
                >
                  Reject
                </button>
              </form>
              <%!-- Defer: with inline reason capture --%>
              <form phx-submit="defer_action" style="display: flex; flex-direction: column; gap: 6px;">
                <input type="hidden" name="approval-id" value={@active_approval.id} />
                <textarea
                  name="reason"
                  placeholder="Reason for deferral (required)"
                  rows="2"
                  style="padding: 6px 8px; border: 1px solid #c38f57; border-radius: 4px; font-size: 0.8rem; width: 100%; resize: vertical;"
                ></textarea>
                <button
                  type="submit"
                  style="padding: 6px 12px; border-radius: 6px; border: 1px solid #7a5c00; background: #fef9e5; color: #7a5c00; font-size: 0.8rem; font-weight: 600; min-height: 32px; cursor: pointer; align-self: flex-start;"
                >
                  Defer
                </button>
              </form>
            </div>
            <p style="font-size: 0.75rem; color: #8b7355; font-style: italic;">A reason is required for rejection or deferral.</p>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  def normalize_context_sections(map) when is_map(map) do
    map
    |> Map.to_list()
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
  end

  def normalize_context_sections(_), do: []

  def humanize_context_label(label) do
    label
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def normalize_context_value(value) when is_binary(value), do: value
  def normalize_context_value(value) when is_number(value), do: to_string(value)
  def normalize_context_value(value) when is_boolean(value), do: to_string(value)

  def normalize_context_value(value) when is_list(value) do
    if Enum.all?(value, fn v -> is_binary(v) or is_number(v) or is_boolean(v) end) do
      Enum.map(value, &normalize_context_value/1) |> Enum.join(", ")
    else
      "Unsupported value"
    end
  end

  def normalize_context_value(_), do: "Unsupported value"

  defp proposal_state_label(%Draft{proposal_type: :clarification}), do: "Clarification required"
  defp proposal_state_label(%Draft{proposal_type: :escalation}), do: "Escalation recommended"
  defp proposal_state_label(_draft), do: "Grounded reply"

  defp draft_operator_summary(%Draft{operator_summary: summary})
       when is_binary(summary) and summary != "",
       do: summary

  defp draft_operator_summary(%Draft{proposal_type: :clarification}) do
    "Grounding is close, but one bounded follow-up is required before a safe reply can be sent."
  end

  defp draft_operator_summary(%Draft{proposal_type: :escalation}) do
    "Grounding is insufficient for a routine reply. Review the evidence and escalate instead of guessing."
  end

  defp draft_operator_summary(_draft) do
    "Grounded reply prepared for operator review."
  end

  defp grounding_reason_label(%Draft{} = draft) do
    case draft_grounding_reason(draft) do
      nil -> nil
      reason -> SearchResultPresenter.diagnostic_reason_label(reason)
    end
  end

  defp grounding_reason_copy(%Draft{} = draft) do
    case draft_grounding_reason(draft) do
      nil -> nil
      reason -> SearchResultPresenter.diagnostic_reason_copy(reason)
    end
  end

  defp draft_grounding_reason(%Draft{grounding_metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, :reason) || Map.get(metadata, "reason")
  end

  defp draft_grounding_reason(_draft), do: nil

  defp draft_evidence(%Draft{evidence_snapshot: %{"evidence" => evidence}})
       when is_list(evidence),
       do: Enum.map(evidence, &to_result/1)

  defp draft_evidence(%Draft{evidence_snapshot: %{evidence: evidence}}) when is_list(evidence),
    do: Enum.map(evidence, &to_result/1)

  defp draft_evidence(_draft), do: []

  defp to_result(%Result{} = result), do: result

  defp to_result(%{} = evidence) do
    evidence
    |> Enum.into(%{}, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      pair -> pair
    end)
    |> then(&struct(Result, &1))
  rescue
    ArgumentError -> struct(Result, %{})
  end

  defp quick_fix_card_state(suggestion, review_task) do
    status = quick_fix_status(suggestion, review_task)

    %{
      status: status,
      summary: quick_fix_summary(suggestion, review_task, status),
      reason: ArticleSuggestionPresenter.quick_fix_reason_label(suggestion),
      layers: ArticleSuggestionPresenter.quick_fix_layers(suggestion),
      primary_action: quick_fix_primary_action(status),
      secondary_action: quick_fix_secondary_action(review_task),
      status_rail: quick_fix_status_rail(status),
      suggestion_id: suggestion.id,
      review_task_id: review_task && review_task.id
    }
  end

  defp idle_quick_fix_card(_conversation) do
    %{
      status: :idle,
      summary:
        "Use conversation evidence to open a KB maintenance task when this thread exposes missing or stale guidance.",
      reason: nil,
      layers: [
        %{label: "Thread context", trust: "Conversation signal", summary: "No bounded thread summary"},
        %{label: "Canonical retrieval", trust: "Citation-eligible", summary: "No citation-ready canonical evidence"},
        %{label: "Resolved case assists", trust: "Supporting context", summary: "No supporting resolved cases"}
      ],
      primary_action: %{event: "start_quick_fix", label: "Start KB quick fix"},
      secondary_action: nil,
      status_rail: quick_fix_status_rail(:idle)
    }
  end

  defp normalize_quick_fix_card(%{quick_fix_card: quick_fix_card, conversation: conversation})
       when is_map(quick_fix_card) do
    Map.merge(idle_quick_fix_card(conversation), quick_fix_card)
  end

  defp normalize_quick_fix_card(%{conversation: conversation}), do: idle_quick_fix_card(conversation)

  defp quick_fix_primary_action(:blocked_manual_required),
    do: %{event: "open_manual_draft", label: "Open manual draft"}

  defp quick_fix_primary_action(_status), do: %{event: "open_review_task", label: "Open review task"}

  defp quick_fix_secondary_action(nil), do: nil

  defp quick_fix_secondary_action(review_task) do
    %{label: "View maintenance lane", to: "/knowledge-base/suggestions?task=#{review_task.id}"}
  end

  defp quick_fix_status(_suggestion, %{status: :published, reindex_status: :completed}), do: :reindexed
  defp quick_fix_status(_suggestion, %{status: :published, reindex_status: :running}), do: :reindexing
  defp quick_fix_status(_suggestion, %{status: :published, reindex_status: :failed}), do: :retry_needed
  defp quick_fix_status(_suggestion, %{status: :published}), do: :published
  defp quick_fix_status(_suggestion, %{status: :approved_ready_to_publish}), do: :approved_ready_to_publish

  defp quick_fix_status(suggestion, _review_task) do
    case ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion) do
      "Draft shell created" -> :shell_created
      "Manual draft required" -> :blocked_manual_required
      _ -> :ready
    end
  end

  defp quick_fix_status_rail(:idle) do
    [%{label: ReviewTaskPresenter.thread_status_label(:idle), current: true}]
  end

  defp quick_fix_status_rail(:shell_created) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:shell_created), current: true},
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false}
    ]
  end

  defp quick_fix_status_rail(:blocked_manual_required) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:blocked_manual_required), current: true},
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false}
    ]
  end

  defp quick_fix_status_rail(:ready) do
    [%{label: ReviewTaskPresenter.thread_status_label(:ready), current: true}]
  end

  defp quick_fix_status_rail(:approved_ready_to_publish) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:approved_ready_to_publish), current: true}
    ]
  end

  defp quick_fix_status_rail(:published) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:approved_ready_to_publish), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:published), current: true}
    ]
  end

  defp quick_fix_status_rail(:reindexing) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:approved_ready_to_publish), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:published), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:reindexing), current: true}
    ]
  end

  defp quick_fix_status_rail(:reindexed) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:approved_ready_to_publish), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:published), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:reindexed), current: true}
    ]
  end

  defp quick_fix_status_rail(:retry_needed) do
    [
      %{label: ReviewTaskPresenter.thread_status_label(:ready), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:approved_ready_to_publish), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:published), current: false},
      %{label: ReviewTaskPresenter.thread_status_label(:retry_needed), current: true}
    ]
  end

  defp quick_fix_summary(_suggestion, review_task, :approved_ready_to_publish) when is_map(review_task) do
    ReviewTaskPresenter.next_step_copy(review_task)
  end

  defp quick_fix_summary(_suggestion, review_task, status)
       when is_map(review_task) and
              status in [:published, :reindexing, :reindexed] do
    ReviewTaskPresenter.publish_outcome(review_task)
  end

  defp quick_fix_summary(%{operator_summary: summary}, review_task, :retry_needed)
       when is_map(review_task) and is_binary(summary) and summary != "" do
    summary
  end

  defp quick_fix_summary(_suggestion, review_task, :retry_needed) when is_map(review_task) do
    ReviewTaskPresenter.publish_outcome(review_task)
  end

  defp quick_fix_summary(suggestion, _review_task, _status) do
    ArticleSuggestionPresenter.quick_fix_summary(suggestion)
  end

  defp quick_fix_request_attrs(conversation) do
    %{
      conversation_id: conversation.id,
      host_user_id: conversation.host_user_id,
      tenant_scope: :host_user_scoped,
      title: conversation.subject,
      thread_context: %{
        conversation_id: conversation.id,
        subject: conversation.subject,
        message_count: length(List.wrap(conversation.messages)),
        message_excerpt: quick_fix_message_excerpt(conversation.messages)
      }
    }
  end

  defp quick_fix_message_excerpt(messages) do
    messages
    |> List.wrap()
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{content: content} when is_binary(content) and content != "" ->
        content
        |> String.trim()
        |> String.slice(0, 280)

      _ ->
        nil
    end)
  end

  defp quick_fix_scope_opts(conversation) do
    [tenant_scope: :host_user_scoped, host_user_id: conversation.host_user_id]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp review_task_path(review_task_id), do: "/knowledge-base/suggestions?task=#{review_task_id}"

  defp manual_review_task_param(nil), do: ""
  defp manual_review_task_param(review_task_id), do: "&review_task_id=#{review_task_id}"

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end
end
