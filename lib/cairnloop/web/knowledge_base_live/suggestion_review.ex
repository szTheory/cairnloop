defmodule Cairnloop.Web.KnowledgeBaseLive.SuggestionReview do
  use Phoenix.LiveView

  import Cairnloop.Web.KnowledgeBaseLive.NavComponent

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff
  alias Cairnloop.Web.{ArticleSuggestionPresenter, ReviewTaskPresenter}

  def mount(_params, session, socket) do
    scope_filters = scope_filters(session)
    queue_filter = nil
    review_tasks = load_review_tasks(scope_filters, queue_filter)
    selected_task = List.first(review_tasks)

    {:ok,
     socket
     |> assign(
       review_tasks: review_tasks,
       selected_task: selected_task,
       selected_diff: selected_diff(selected_task),
       scope_filters: scope_filters,
       queue_filter: queue_filter
     )}
  end

  def handle_params(params, _uri, socket) do
    queue_filter = Map.get(params, "queue") |> ReviewTaskPresenter.queue_filter_status()
    review_tasks = load_review_tasks(socket.assigns.scope_filters, queue_filter)

    selected_task =
      cond do
        task_id = params["task"] ->
          task_id
          |> String.to_integer()
          |> knowledge_automation().get_review_task!(socket.assigns.scope_filters)

        suggestion_id = params["suggestion"] ->
          {:ok, task} =
            suggestion_id
            |> String.to_integer()
            |> knowledge_automation().ensure_review_task_for_suggestion(
              socket.assigns.scope_filters
            )

          knowledge_automation().get_review_task!(task.id, socket.assigns.scope_filters)

        true ->
          List.first(review_tasks)
      end

    {:noreply,
     socket
     |> assign(
       review_tasks: review_tasks,
       queue_filter: queue_filter
     )
     |> assign_selected(selected_task)}
  end

  def handle_event("regenerate", %{"id" => task_id}, socket) do
    with {:ok, task, suggestion} <- load_task_selection(task_id, socket),
         {:ok, _suggestion} <-
           knowledge_automation().regenerate_article_suggestion(
             suggestion.id,
             socket.assigns.scope_filters
           ) do
      {:noreply, reload_selected(socket, task.id)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Unable to regenerate this suggestion right now.")}
    end
  end

  def handle_event("dismiss", %{"id" => task_id}, socket) do
    with {:ok, task, suggestion} <- load_task_selection(task_id, socket),
         {:ok, _suggestion} <-
           knowledge_automation().dismiss_article_suggestion(
             suggestion.id,
             socket.assigns.scope_filters
           ) do
      {:noreply, reload_selected(socket, task.id)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Unable to dismiss this suggestion right now.")}
    end
  end

  def handle_event("approve", %{"id" => task_id}, socket) do
    case knowledge_automation().approve_review_task(
           normalize_id(task_id),
           socket.assigns.scope_filters
         ) do
      {:ok, task} ->
        {:noreply, reload_selected(socket, task.id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to approve this review task right now.")}
    end
  end

  def handle_event("reject", %{"id" => task_id}, socket) do
    case knowledge_automation().reject_review_task(
           normalize_id(task_id),
           Keyword.put(socket.assigns.scope_filters, :reason, :insufficient_evidence)
         ) do
      {:ok, task} ->
        {:noreply, reload_selected(socket, task.id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to reject this review task right now.")}
    end
  end

  def handle_event("defer", %{"id" => task_id}, socket) do
    case knowledge_automation().defer_review_task(
           normalize_id(task_id),
           Keyword.put(socket.assigns.scope_filters, :reason, :needs_manual_edit)
         ) do
      {:ok, task} ->
        {:noreply, reload_selected(socket, task.id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to defer this review task right now.")}
    end
  end

  def handle_event("publish", %{"id" => task_id}, socket) do
    case knowledge_automation().publish_review_task(
           normalize_id(task_id),
           socket.assigns.scope_filters
         ) do
      {:ok, task} ->
        {:noreply, reload_selected(socket, task.id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to publish this review task right now.")}
    end
  end

  def handle_event("open_for_manual_edit", %{"id" => task_id}, socket) do
    with {:ok, task, suggestion} <- load_task_selection(task_id, socket),
         {:ok, target_article_id} <- resolve_target_article_id(suggestion, socket),
         {:ok, _suggestion, opened_at_iso} <-
           knowledge_automation().record_editor_handoff(
             suggestion.id,
             socket.assigns.scope_filters
           ) do
      return_to =
        task.id
        |> task_patch(socket.assigns.queue_filter)
        |> URI.encode_www_form()

      handoff_token =
        EditorHandoff.sign(
          suggestion.id,
          target_article_id,
          task.id,
          URI.decode_www_form(return_to),
          manual_edit_opened_at: opened_at_iso
        )

      {:noreply,
       push_navigate(
         socket,
         to:
           "/knowledge-base/#{target_article_id}/edit?suggestion_id=#{suggestion.id}" <>
             "&review_task_id=#{task.id}&return_to=#{return_to}&handoff=#{URI.encode_www_form(handoff_token)}"
       )}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Unable to open the editor right now. Try again.")}
    end
  end

  defp resolve_target_article_id(%{suggestion_type: :revision, article_id: article_id}, _socket),
    do: {:ok, article_id}

  defp resolve_target_article_id(suggestion, socket) do
    knowledge_automation().create_or_reuse_authoring_article_for_suggestion(
      suggestion.id,
      socket.assigns.scope_filters
    )
  end

  def render(assigns) do
    ~H"""
    <div class="suggestion-review">
      <.kb_nav current={:suggestions} />
      <header>
        <h1>Suggestion review</h1>
        <p>Inspect grounded KB proposals before any manual editing or later publish workflow begins.</p>
      </header>

      <section>
        <h2>Suggestion filters</h2>
        <ul>
          <%= for {filter, label} <- ReviewTaskPresenter.queue_filters() do %>
            <li>
              <.link patch={queue_patch(filter, @selected_task)}>
                <strong><%= label %></strong>
              </.link>
            </li>
          <% end %>
        </ul>
      </section>

      <section>
        <ul>
          <%= for task <- @review_tasks do %>
            <% suggestion = task.article_suggestion %>
            <li id={"review-task-#{task.id}"}>
              <.link patch={task_patch(task.id, @queue_filter)}>
                <strong><%= task_title(task) %></strong>
              </.link>
              <div><%= ArticleSuggestionPresenter.status_label(suggestion) %></div>
              <div><%= ArticleSuggestionPresenter.queue_summary(suggestion) %></div>
            </li>
          <% end %>
        </ul>
      </section>

      <%= if @selected_task do %>
        <% suggestion = @selected_task.article_suggestion %>
        <section id="suggestion-detail">
          <h2><%= task_title(@selected_task) %></h2>
          <p><strong>Review task status</strong>: <%= ReviewTaskPresenter.status_label(@selected_task) %></p>
          <p><strong>Next step</strong>: <%= ReviewTaskPresenter.next_step_copy(@selected_task) %></p>
          <p><strong>Decision summary</strong>: <%= ReviewTaskPresenter.decision_summary(@selected_task) %></p>
          <p><strong>Suggestion status</strong>: <%= ArticleSuggestionPresenter.status_label(suggestion) %></p>
          <p><strong>Grounding status</strong>: <%= ArticleSuggestionPresenter.grounding_status_label(suggestion) %></p>
          <p><strong>Stale pressure</strong>: <%= ArticleSuggestionPresenter.stale_pressure_label(suggestion) %></p>
          <p><%= suggestion.operator_summary %></p>

          <%= if ArticleSuggestionPresenter.quick_fix?(suggestion) do %>
            <section id="quick-fix-context">
              <p><strong>Quick-fix outcome</strong>: <%= ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion) %></p>
              <p><strong>Launch context</strong>: <%= ArticleSuggestionPresenter.quick_fix_launch_context(suggestion) %></p>
              <%= if excerpt = ArticleSuggestionPresenter.quick_fix_message_excerpt(suggestion) do %>
                <p><%= excerpt %></p>
              <% end %>

              <h3>Evidence layers</h3>
              <ul>
                <%= for layer <- ArticleSuggestionPresenter.quick_fix_layers(suggestion) do %>
                  <li>
                    <strong><%= layer.label %></strong>
                    ·
                    <strong><%= layer.trust %></strong>
                    <div><%= layer.summary %></div>
                  </li>
                <% end %>
              </ul>

              <%= if reason = ArticleSuggestionPresenter.quick_fix_reason_label(suggestion) do %>
                <p><strong>Quick-fix reason</strong>: <%= reason %></p>
              <% end %>
            </section>
          <% end %>

          <div>
            <%= for {event, label} <- review_actions(@selected_task) do %>
              <button phx-click={event} phx-value-id={@selected_task.id}>
                <%= label %>
              </button>
            <% end %>
          </div>

          <h3>Evidence</h3>
          <ul>
            <%= for evidence <- suggestion.evidence_snapshot do %>
              <li>
                <strong><%= ArticleSuggestionPresenter.source_label(evidence) %></strong>
                ·
                <strong><%= ArticleSuggestionPresenter.trust_label(evidence) %></strong>
                <%= if ArticleSuggestionPresenter.citation_anchor(evidence) != "" do %>
                  ·
                  <span><%= ArticleSuggestionPresenter.citation_anchor(evidence) %></span>
                <% end %>
                <div><%= evidence.title %></div>
                <div><%= evidence.excerpt %></div>
                <%= if path = ArticleSuggestionPresenter.evidence_path(evidence) do %>
                  <div><%= path %></div>
                <% end %>
              </li>
            <% end %>
          </ul>

          <%= if suggestion.status == :failed do %>
            <h3>Failure details</h3>
            <p><%= ArticleSuggestionPresenter.failure_copy(suggestion) %></p>
          <% else %>
            <%= if suggestion.suggestion_type == :revision do %>
              <h3>Derived diff summary</h3>
              <pre><%= @selected_diff %></pre>
            <% else %>
              <h3>Proposed markdown</h3>
              <pre><%= suggestion.proposed_markdown %></pre>
            <% end %>
          <% end %>

          <h3>Structured history</h3>
          <ul>
            <%= for event <- @selected_task.events do %>
              <li><%= ReviewTaskPresenter.history_line(event) %></li>
            <% end %>
          </ul>

          <%= if @selected_task.status == :published do %>
            <h3>Publish outcome</h3>
            <p><%= ReviewTaskPresenter.publish_outcome(@selected_task) %></p>
          <% end %>
        </section>
      <% end %>
    </div>
    """
  end

  defp load_review_tasks(scope_filters, queue_filter) do
    scope_filters
    |> queue_filter_opts(queue_filter)
    |> Keyword.put(:preload, [:article_suggestion, :events])
    |> knowledge_automation().list_review_tasks()
  end

  defp queue_filter_opts(scope_filters, nil), do: scope_filters

  defp queue_filter_opts(scope_filters, queue_filter),
    do: Keyword.put(scope_filters, :status, queue_filter)

  defp assign_selected(socket, nil) do
    assign(socket, selected_task: nil, selected_diff: nil)
  end

  defp assign_selected(socket, task) do
    assign(socket, selected_task: task, selected_diff: selected_diff(task))
  end

  defp selected_diff(nil), do: nil

  defp selected_diff(task) do
    suggestion = task.article_suggestion

    if suggestion.suggestion_type == :revision and suggestion.base_revision_id do
      suggestion.base_revision_id
      |> knowledge_base().get_revision()
      |> case do
        nil -> suggestion.proposed_markdown
        revision -> ArticleSuggestionPresenter.revision_diff(suggestion, revision.content)
      end
    end
  end

  defp task_title(%{article_suggestion: %{title: title}}) when is_binary(title) and title != "",
    do: title

  defp task_title(_task), do: "Untitled suggestion"

  defp review_actions(task) do
    task
    |> ReviewTaskPresenter.available_actions()
    |> Enum.map(fn
      :open_for_edit ->
        {"open_for_manual_edit", ReviewTaskPresenter.action_label(:open_for_edit, task)}

      action ->
        {Atom.to_string(action), ReviewTaskPresenter.action_label(action, task)}
    end)
  end

  defp load_task_selection(task_id, socket) do
    task =
      knowledge_automation().get_review_task!(
        String.to_integer(task_id),
        socket.assigns.scope_filters
      )

    {:ok, task, task.article_suggestion}
  end

  defp reload_selected(socket, task_id) do
    task_id = normalize_id(task_id)
    review_tasks = load_review_tasks(socket.assigns.scope_filters, socket.assigns.queue_filter)
    selected_task = knowledge_automation().get_review_task!(task_id, socket.assigns.scope_filters)

    socket
    |> assign(review_tasks: review_tasks)
    |> assign_selected(selected_task)
  end

  defp normalize_id(value) when is_binary(value), do: String.to_integer(value)
  defp normalize_id(value), do: value

  defp task_patch(task_id, nil), do: "/knowledge-base/suggestions?task=#{task_id}"

  defp task_patch(task_id, queue_filter),
    do: "/knowledge-base/suggestions?task=#{task_id}&queue=#{queue_filter}"

  defp queue_patch(filter, nil), do: queue_patch(filter, 0)

  defp queue_patch(filter, selected_task) do
    task_id =
      case selected_task do
        %{id: id} -> id
        _ -> nil
      end

    params =
      []
      |> maybe_put_param("queue", filter)
      |> maybe_put_param("task", task_id)
      |> Enum.join("&")

    "/knowledge-base/suggestions" <> if(params == "", do: "", else: "?#{params}")
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, "queue", "all"), do: params
  defp maybe_put_param(params, key, value), do: params ++ ["#{key}=#{value}"]

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end

  defp knowledge_base do
    Application.get_env(:cairnloop, :knowledge_base, Cairnloop.KnowledgeBase)
  end

  defp scope_filters(session) do
    host_user_id = Map.get(session, "host_user_id") || Map.get(session, :host_user_id)

    if host_user_id do
      [tenant_scope: :host_user_scoped, host_user_id: to_string(host_user_id)]
    else
      []
    end
  end
end
