defmodule Cairnloop.Web.KnowledgeBaseLive.Gaps do
  use Phoenix.LiveView

  import Cairnloop.Web.Components
  import Cairnloop.Web.KnowledgeBaseLive.NavComponent

  alias Cairnloop.Web.GapCandidatePresenter

  def mount(_params, session, socket) do
    candidates = knowledge_automation().list_gap_candidates(scope_filters(session))

    {:ok,
     assign(socket,
       candidates: candidates,
       selected_candidate: nil,
       scope_filters: scope_filters(session)
     )}
  end

  def handle_params(%{"candidate" => candidate_id}, _uri, socket) do
    candidate =
      candidate_id
      |> String.to_integer()
      |> knowledge_automation().get_gap_candidate!(socket.assigns.scope_filters)

    {:noreply, assign(socket, selected_candidate: candidate)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, selected_candidate: nil)}
  end

  def handle_event("suggest_article", %{"candidate_id" => candidate_id}, socket) do
    attrs = %{
      entrypoint_id: String.to_integer(candidate_id),
      gap_candidate_id: String.to_integer(candidate_id),
      title: socket.assigns.selected_candidate && socket.assigns.selected_candidate.title,
      tenant_scope: Keyword.get(socket.assigns.scope_filters, :tenant_scope, :system_unscoped),
      host_user_id: Keyword.get(socket.assigns.scope_filters, :host_user_id)
    }

    case knowledge_automation().suggest_article(attrs) do
      {:ok, suggestion} ->
        with {:ok, task} <-
               knowledge_automation().ensure_review_task_for_suggestion(
                 suggestion.id,
                 socket.assigns.scope_filters
               ) do
          {:noreply, push_navigate(socket, to: "/knowledge-base/suggestions?task=#{task.id}")}
        else
          _ ->
            {:noreply,
             put_flash(socket, :error, "Unable to open the shared review task right now.")}
        end

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Unable to create the article suggestion right now.")}
    end
  end

  def render(assigns) do
    ~H"""
    <.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page
        title="Knowledge gaps"
        subtitle="Ranked maintenance signals from retrieval misses, weak grounding, and repeated manual handling."
        width="wide"
      >
        <:subnav><.kb_nav current={:gaps} /></:subnav>

        <.cl_card class="cl-mb-7">
        <:header><h2>Gap candidates</h2></:header>

        <.cl_empty :if={@candidates == []} title="No gap candidates yet." icon="compass">
          <p class="cl-text-muted">When repeatable evidence lands, this queue will show it here.</p>
        </.cl_empty>

        <ul :if={@candidates != []} class="cl-stack--lg cl-stack">
          <li :for={candidate <- @candidates} id={"candidate-#{candidate.id}"} class="cl-stack">
            <div class="cl-row cl-row--wrap cl-row--between">
              <.link patch={"/knowledge-base/gaps?candidate=#{candidate.id}"}>
                <strong>{candidate.title}</strong>
              </.link>
              <.cl_chip variant="info" label={GapCandidatePresenter.reason_label(candidate)} />
            </div>
            <div class="cl-row cl-row--wrap cl-text-small cl-text-muted">
              <.cl_chip variant="neutral" label={"#{candidate.evidence_count} signals"} />
              <.cl_chip variant="neutral" label={"#{candidate.manual_case_count} manual cases"} />
              <span>{GapCandidatePresenter.freshness_label(candidate)}</span>
              <span>{GapCandidatePresenter.dominant_source_label(candidate)}</span>
            </div>
          </li>
        </ul>
      </.cl_card>

      <.cl_card :if={@selected_candidate} id="candidate-detail" class="cl-mb-7">
        <:header>
          <div class="cl-row cl-row--wrap cl-row--between">
            <h2>{@selected_candidate.title}</h2>
            <.cl_button
              variant="primary"
              phx-click="suggest_article"
              phx-value-candidate_id={@selected_candidate.id}
            >
              Generate article suggestion
            </.cl_button>
          </div>
        </:header>

        <p class="cl-text-muted">{GapCandidatePresenter.why_raised(@selected_candidate)}</p>

        <hr class="cl-divider" />
        <h3>Retrieval evidence</h3>
        <.cl_empty
          :if={@selected_candidate.retrieval_gap_events == []}
          title="No retrieval evidence linked."
          icon="search"
        />
        <ul :if={@selected_candidate.retrieval_gap_events != []} class="cl-stack">
          <li :for={event <- @selected_candidate.retrieval_gap_events} class="cl-stack">
            <div class="cl-row cl-row--wrap">
              <strong>{GapCandidatePresenter.event_reason_label(event.reason)}</strong>
              <.cl_chip variant="neutral" label={GapCandidatePresenter.surface_label(event.surface)} />
            </div>
            <div class="cl-text-small cl-text-muted">
              {event.canonical_hit_count} canonical / {event.assistive_hit_count} assistive hits
            </div>
            <div class="cl-text-small cl-mono">{event.sanitized_query_excerpt}</div>
          </li>
        </ul>

        <hr class="cl-divider" />
        <h3>Similar resolved cases</h3>
        <.cl_empty
          :if={@selected_candidate.manual_handling_evidence == []}
          title="No repeated manual-handling evidence linked."
          icon="inbox"
        />
        <ul :if={@selected_candidate.manual_handling_evidence != []} class="cl-stack">
          <li :for={evidence <- @selected_candidate.manual_handling_evidence} class="cl-stack">
            <strong>{evidence.issue_summary}</strong>
            <div class="cl-text-small">{evidence.resolution_note}</div>
            <div class="cl-text-small cl-text-muted">{Enum.join(evidence.actions_taken || [], ", ")}</div>
            <.link
              :if={GapCandidatePresenter.conversation_target(evidence)}
              navigate={GapCandidatePresenter.conversation_target(evidence)}
            >
              Open conversation
            </.link>
          </li>
        </ul>
        </.cl_card>
      </.cl_page>
    </.cl_shell>
    """
  end

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, Cairnloop.KnowledgeAutomation)
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
