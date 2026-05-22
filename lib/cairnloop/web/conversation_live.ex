defmodule Cairnloop.Web.ConversationLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat
  alias Cairnloop.Automation.Draft
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Retrieval.Result
  alias Cairnloop.Web.{ArticleSuggestionPresenter, ReviewTaskPresenter, SearchResultPresenter}

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

  def handle_event("execute_tool", %{"tool" => tool_name} = params, socket) do
    tool_module = String.to_existing_atom(tool_name)
    actor_id = socket.assigns.conversation.host_user_id
    context = socket.assigns.host_context

    # Authorization
    if tool_module.can_execute?(actor_id, context) do
      tool_params = params["tool_params"] || %{}
      changeset = tool_module.changeset(struct(tool_module), tool_params)

      if changeset.valid? do
        tool_struct = Ecto.Changeset.apply_changes(changeset)

        try do
          case tool_module.execute(tool_struct, actor_id, context) do
            {:ok, result} ->
              {:noreply, put_flash(socket, :info, result)}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Execution failed: #{inspect(reason)}")}
          end
        rescue
          e ->
            {:noreply,
             put_flash(socket, :error, "Tool execution failed: #{Exception.message(e)}")}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid tool parameters.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Not authorized to execute this tool.")}
    end
  end

  defp reload_conversation_with_context(socket, conversation_id) do
    conversation = Chat.get_conversation!(conversation_id)
    {context, context_error} = load_host_context(conversation)
    quick_fix_card = load_quick_fix_card(conversation)

    assign(socket,
      conversation: conversation,
      host_context: context,
      context_error: context_error,
      quick_fix_card: quick_fix_card
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
            <button type="submit" style="padding: 6px 12px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer; align-self: flex-start;">Execute</button>
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
      summary: ArticleSuggestionPresenter.quick_fix_summary(suggestion),
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

  defp quick_fix_primary_action(:idle), do: %{event: "start_quick_fix", label: "Start KB quick fix"}

  defp quick_fix_primary_action(:blocked_manual_required),
    do: %{event: "open_manual_draft", label: "Open manual draft"}

  defp quick_fix_primary_action(_status), do: %{event: "open_review_task", label: "Open review task"}

  defp quick_fix_secondary_action(nil), do: nil

  defp quick_fix_secondary_action(review_task) do
    %{label: "View maintenance lane", to: "/knowledge-base/suggestions?task=#{review_task.id}"}
  end

  defp quick_fix_status(_suggestion, %{status: :published, reindex_status: :completed}), do: :reindexed
  defp quick_fix_status(_suggestion, %{status: :published, reindex_status: :running}), do: :reindexing
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

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end
end
