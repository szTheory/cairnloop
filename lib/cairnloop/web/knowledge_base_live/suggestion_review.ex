defmodule Cairnloop.Web.KnowledgeBaseLive.SuggestionReview do
  use Phoenix.LiveView

  import Cairnloop.Web.Components
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
    <.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page
        title="Suggestion review"
        subtitle="Inspect grounded KB proposals before any manual editing or later publish workflow begins."
        width="wide"
      >
        <:subnav><.kb_nav current={:suggestions} /></:subnav>

        <.cl_card class="cl-mb-7">
        <:header><h2>Suggestion filters</h2></:header>
        <div class="cl-row cl-row--wrap">
          <.link
            :for={{filter, label} <- ReviewTaskPresenter.queue_filters()}
            patch={queue_patch(filter, @selected_task)}
            class="cl-button cl-button--ghost cl-button--sm"
          >
            {label}
          </.link>
        </div>
      </.cl_card>

      <.cl_card class="cl-mb-7">
        <:header><h2>Review queue</h2></:header>

        <.cl_empty :if={@review_tasks == []} title="No suggestions in this queue" icon="compass">
          <p class="cl-text-muted">
            Grounded proposals land here as gaps and stale-pressure signals surface. Nothing is waiting on you right now.
          </p>
        </.cl_empty>

        <div :if={@review_tasks != []} class="cl-table-scroll" role="region" tabindex="0" aria-label="Suggested KB edits">
        <table class="cl-table">
          <thead>
            <tr><th>Suggestion</th><th>Suggestion status</th><th>Summary</th></tr>
          </thead>
          <tbody>
            <tr :for={task <- @review_tasks} id={"review-task-#{task.id}"}>
              <td>
                <.link patch={task_patch(task.id, @queue_filter)}>{task_title(task)}</.link>
              </td>
              <td>
                <.cl_chip
                  variant={suggestion_status_variant(task.article_suggestion)}
                  label={ArticleSuggestionPresenter.status_label(task.article_suggestion)}
                />
              </td>
              <td class="cl-text-muted">{ArticleSuggestionPresenter.queue_summary(task.article_suggestion)}</td>
            </tr>
          </tbody>
        </table>
        </div>
      </.cl_card>

      <%= if @selected_task do %>
        <% suggestion = @selected_task.article_suggestion %>
        <.cl_card id="suggestion-detail" class="cl-mb-7">
          <:header>
            <h2>{task_title(@selected_task)}</h2>
            <.cl_chip
              variant={review_status_variant(@selected_task)}
              label={ReviewTaskPresenter.status_label(@selected_task)}
            />
          </:header>

          <div class="cl-stack cl-mb-7">
            <p><strong>Review task status</strong>: {ReviewTaskPresenter.status_label(@selected_task)}</p>
            <p><strong>Next step</strong>: {ReviewTaskPresenter.next_step_copy(@selected_task)}</p>
            <p><strong>Decision summary</strong>: {ReviewTaskPresenter.decision_summary(@selected_task)}</p>
            <p><strong>Suggestion status</strong>: {ArticleSuggestionPresenter.status_label(suggestion)}</p>
            <p><strong>Grounding status</strong>: {ArticleSuggestionPresenter.grounding_status_label(suggestion)}</p>
            <p><strong>Stale pressure</strong>: {ArticleSuggestionPresenter.stale_pressure_label(suggestion)}</p>
          </div>

          <.cl_banner variant="info" class="cl-mb-7">{suggestion.operator_summary}</.cl_banner>

          <div :if={review_actions(@selected_task) != []} class="cl-row cl-row--wrap cl-mb-7">
            <.cl_button
              :for={{event, label} <- review_actions(@selected_task)}
              variant={action_variant(event)}
              phx-click={event}
              phx-value-id={@selected_task.id}
            >
              {label}
            </.cl_button>
          </div>
        </.cl_card>

        <.cl_card :if={ArticleSuggestionPresenter.quick_fix?(suggestion)} id="quick-fix-context" class="cl-mb-7">
          <:header><h2>Quick-fix context</h2></:header>
          <div class="cl-stack cl-mb-7">
            <p><strong>Quick-fix outcome</strong>: {ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion)}</p>
            <p><strong>Launch context</strong>: {ArticleSuggestionPresenter.quick_fix_launch_context(suggestion)}</p>
            <p :if={excerpt = ArticleSuggestionPresenter.quick_fix_message_excerpt(suggestion)} class="cl-text-muted">
              {excerpt}
            </p>
          </div>

          <h3 class="cl-mb-7">Evidence layers</h3>
          <ul class="cl-stack cl-mb-7">
            <li :for={layer <- ArticleSuggestionPresenter.quick_fix_layers(suggestion)} class="cl-list-row">
              <div class="cl-row cl-row--wrap">
                <strong>{layer.label}</strong>
                <.cl_chip variant="ai" label={layer.trust} />
              </div>
              <div class="cl-text-muted">{layer.summary}</div>
            </li>
          </ul>

          <.cl_banner
            :if={reason = ArticleSuggestionPresenter.quick_fix_reason_label(suggestion)}
            variant="warning"
          >
            <strong>Quick-fix reason</strong>: {reason}
          </.cl_banner>
        </.cl_card>

        <.cl_card class="cl-mb-7">
          <:header><h2>Evidence</h2></:header>
          <.cl_empty :if={suggestion.evidence_snapshot == []} title="No evidence captured yet" icon="search">
            <p class="cl-text-muted">This proposal carries no snapshotted citations.</p>
          </.cl_empty>
          <ul :if={suggestion.evidence_snapshot != []} class="cl-stack">
            <li :for={evidence <- suggestion.evidence_snapshot} class="cl-list-row">
              <div class="cl-row cl-row--wrap">
                <strong>{ArticleSuggestionPresenter.source_label(evidence)}</strong>
                <.cl_chip variant="info" label={ArticleSuggestionPresenter.trust_label(evidence)} />
                <span :if={ArticleSuggestionPresenter.citation_anchor(evidence) != ""} class="cl-text-muted cl-text-small">
                  {ArticleSuggestionPresenter.citation_anchor(evidence)}
                </span>
              </div>
              <div>{evidence.title}</div>
              <div class="cl-text-muted">{evidence.excerpt}</div>
              <div :if={path = ArticleSuggestionPresenter.evidence_path(evidence)} class="cl-text-muted cl-text-small cl-mono">
                {path}
              </div>
            </li>
          </ul>
        </.cl_card>

        <.cl_card class="cl-mb-7">
          <:header><h2>{proposal_section_title(suggestion)}</h2></:header>
          <%= cond do %>
            <% suggestion.status == :failed -> %>
              <.cl_banner variant="danger">{ArticleSuggestionPresenter.failure_copy(suggestion)}</.cl_banner>
            <% suggestion.suggestion_type == :revision -> %>
              <pre class="cl-code-block">{@selected_diff}</pre>
            <% true -> %>
              <pre class="cl-code-block">{suggestion.proposed_markdown}</pre>
          <% end %>
        </.cl_card>

        <.cl_card class="cl-mb-7">
          <:header><h2>Structured history</h2></:header>
          <ul class="cl-stack">
            <li :for={event <- @selected_task.events} class="cl-list-row">
              {ReviewTaskPresenter.history_line(event)}
            </li>
          </ul>
        </.cl_card>

        <.cl_card :if={@selected_task.status == :published} class="cl-mb-7">
          <:header><h2>Publish outcome</h2></:header>
          <.cl_banner variant="success">{ReviewTaskPresenter.publish_outcome(@selected_task)}</.cl_banner>
        </.cl_card>
      <% end %>
      </.cl_page>
    </.cl_shell>
    """
  end

  # Title for the proposal-content card, matching the underlying content shown.
  defp proposal_section_title(%{status: :failed}), do: "Failure details"
  defp proposal_section_title(%{suggestion_type: :revision}), do: "Derived diff summary"
  defp proposal_section_title(_suggestion), do: "Proposed markdown"

  # Chip variant for an article-suggestion status (color + icon + text via cl_chip).
  defp suggestion_status_variant(%{status: :ready}), do: "success"
  defp suggestion_status_variant(%{status: :pending_generation}), do: "info"
  defp suggestion_status_variant(%{status: :failed}), do: "danger"
  defp suggestion_status_variant(_suggestion), do: "neutral"

  # Chip variant for a review-task status.
  defp review_status_variant(%{status: :approved_ready_to_publish}), do: "success"
  defp review_status_variant(%{status: :published}), do: "success"
  defp review_status_variant(%{status: :pending_review}), do: "info"
  defp review_status_variant(%{status: :review_needed}), do: "warning"
  defp review_status_variant(%{status: :deferred}), do: "warning"
  defp review_status_variant(%{status: :rejected}), do: "danger"
  defp review_status_variant(_task), do: "neutral"

  # Button intent per review action event.
  defp action_variant("approve"), do: "primary"
  defp action_variant("publish"), do: "primary"
  defp action_variant("reject"), do: "danger"
  defp action_variant("dismiss"), do: "danger"
  defp action_variant(_event), do: "ghost"

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
