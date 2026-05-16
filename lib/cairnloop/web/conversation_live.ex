defmodule Cairnloop.Web.ConversationLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

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
          |> assign(form: to_form(%{"content" => draft.content}))

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

    assign(socket,
      conversation: conversation,
      host_context: context,
      context_error: context_error
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

  def render(assigns) do
    ~H"""
    <.live_component module={Cairnloop.Web.SearchModalComponent} id="search-modal" />
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
        background: #f9fafb;
        border: 1px solid #e5e7eb;
        border-radius: 8px;
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
    ~H"""
    <div class="rail-card draft">
      <h3>AI Draft / Audit</h3>
      <p><strong>Draft:</strong> <%= @draft.content %></p>
      <p><em>Status: <%= @draft.status %></em></p>
      
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
end
