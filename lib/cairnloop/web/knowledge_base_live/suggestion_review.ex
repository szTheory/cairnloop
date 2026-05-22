defmodule Cairnloop.Web.KnowledgeBaseLive.SuggestionReview do
  use Phoenix.LiveView

  alias Cairnloop.KnowledgeAutomation
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
            |> knowledge_automation().ensure_review_task_for_suggestion(socket.assigns.scope_filters)

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

  def handle_event("approve", %{"id" => task_id}, socket) do
    case knowledge_automation().approve_review_task(String.to_integer(task_id), socket.assigns.scope_filters) do
      {:ok, _task} -> {:noreply, reload_selected(socket, task_id)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Unable to approve this review task right now.")}
    end
  end

  def handle_event("reject", %{"id" => task_id}, socket) do
    opts = Keyword.put(socket.assigns.scope_filters, :reason, :insufficient_evidence)

    case knowledge_automation().reject_review_task(String.to_integer(task_id), opts) do
      {:ok, _task} -> {:noreply, reload_selected(socket, task_id)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Unable to reject this review task right now.")}
    end
  end

  def handle_event("defer", %{"id" => task_id}, socket) do
    opts = Keyword.put(socket.assigns.scope_filters, :reason, :needs_manual_edit)

    case knowledge_automation().defer_review_task(String.to_integer(task_id), opts) do
      {:ok, _task} -> {:noreply, reload_selected(socket, task_id)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Unable to defer this review task right now.")}
    end
  end

  def handle_event("publish", %{"id" => task_id}, socket) do
    case knowledge_automation().publish_review_task(String.to_integer(task_id), socket.assigns.scope_filters) do
      {:ok, _task} -> {:noreply, reload_selected(socket, task_id)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Unable to publish this review task right now.")}
    end
  end

  def handle_event("open_for_edit", %{"id" => task_id}, socket) do
    task_id = String.to_integer(task_id)
    task = knowledge_automation().get_review_task!(task_id, socket.assigns.scope_filters)
    suggestion = task.article_suggestion

    target_article_id =
      if suggestion.suggestion_type == :revision do
        suggestion.article_id
      else
        {:ok, article_id} =
          knowledge_automation().create_or_reuse_authoring_article_for_suggestion(
            suggestion.id,
            socket.assigns.scope_filters
          )

        article_id
      end

    return_to =
      task.id
      |> task_patch(socket.assigns.queue_filter)
      |> URI.encode_www_form()

    {:noreply,
     push_navigate(
       socket,
       to:
         "/knowledge-base/#{target_article_id}/edit?suggestion_id=#{suggestion.id}" <>
           "&review_task_id=#{task.id}&return_to=#{return_to}"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="suggestion-review">
      <header>
        <h1>Review inbox</h1>
        <p>Keep AI proposal truth, operator decision truth, and publish follow-through in one lane.</p>
      </header>

      <section>
        <h2>Queue filters</h2>
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
            <li id={"review-task-#{task.id}"}>
              <.link patch={task_patch(task.id, @queue_filter)}>
                <strong><%= task_title(task) %></strong>
              </.link>
              <div><%= ReviewTaskPresenter.status_label(task) %></div>
              <div><%= ReviewTaskPresenter.next_step_copy(task) %></div>
            </li>
          <% end %>
        </ul>
      </section>

      <%= if @selected_task do %>
        <% suggestion = @selected_task.article_suggestion %>
        <section id="suggestion-detail">
          <h2><%= task_title(@selected_task) %></h2>
          <p><strong>AI proposal status</strong>: <%= ArticleSuggestionPresenter.status_label(suggestion) %></p>
          <p><strong>Task status</strong>: <%= ReviewTaskPresenter.status_label(@selected_task) %></p>
          <p><strong>Decision summary</strong>: <%= ReviewTaskPresenter.decision_summary(@selected_task) %></p>
          <p><strong>Publish outcome</strong>: <%= ReviewTaskPresenter.publish_outcome(@selected_task) %></p>
          <p><%= suggestion.operator_summary %></p>

          <div>
            <%= for action <- ReviewTaskPresenter.available_actions(@selected_task) do %>
              <button phx-click={Atom.to_string(action)} phx-value-id={@selected_task.id}>
                <%= ReviewTaskPresenter.action_label(action) %>
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
        </section>
      <% end %>
    </div>
    """
  end

  defp load_review_tasks(scope_filters, queue_filter) do
    scope_filters
    |> queue_filter_opts(queue_filter)
    |> knowledge_automation().list_review_tasks()
    |> Enum.map(fn task -> knowledge_automation().get_review_task!(task.id, scope_filters) end)
  end

  defp queue_filter_opts(scope_filters, nil), do: scope_filters
  defp queue_filter_opts(scope_filters, queue_filter), do: Keyword.put(scope_filters, :status, queue_filter)

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

  defp reload_selected(socket, task_id) do
    review_tasks = load_review_tasks(socket.assigns.scope_filters, socket.assigns.queue_filter)
    selected_task = knowledge_automation().get_review_task!(String.to_integer(task_id), socket.assigns.scope_filters)

    socket
    |> assign(review_tasks: review_tasks)
    |> assign_selected(selected_task)
  end

  defp task_patch(task_id, nil), do: "/knowledge-base/suggestions?task=#{task_id}"
  defp task_patch(task_id, queue_filter), do: "/knowledge-base/suggestions?task=#{task_id}&queue=#{queue_filter}"

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
