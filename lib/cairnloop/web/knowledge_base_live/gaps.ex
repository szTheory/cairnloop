defmodule Cairnloop.Web.KnowledgeBaseLive.Gaps do
  use Phoenix.LiveView

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
    <div class="knowledge-base-gaps">
      <header>
        <h1>KB gap candidates</h1>
        <p>Ranked maintenance signals from retrieval misses, weak grounding, and repeated manual handling.</p>
      </header>

      <%= if @candidates == [] do %>
        <section>
          <p>No gap candidates yet.</p>
          <p>When repeatable evidence lands, this queue will show it here.</p>
        </section>
      <% else %>
        <section>
          <ul>
            <%= for candidate <- @candidates do %>
              <li id={"candidate-#{candidate.id}"}>
                <.link patch={"/knowledge-base/gaps?candidate=#{candidate.id}"}>
                  <strong><%= candidate.title %></strong>
                </.link>
                <div><%= GapCandidatePresenter.reason_label(candidate) %></div>
                <div><%= candidate.evidence_count %> signals</div>
                <div><%= candidate.manual_case_count %> manual cases</div>
                <div><%= GapCandidatePresenter.freshness_label(candidate) %></div>
                <div><%= GapCandidatePresenter.dominant_source_label(candidate) %></div>
              </li>
            <% end %>
          </ul>
        </section>
      <% end %>

      <%= if @selected_candidate do %>
        <section id="candidate-detail">
          <h2><%= @selected_candidate.title %></h2>
          <p><%= GapCandidatePresenter.why_raised(@selected_candidate) %></p>
          <button phx-click="suggest_article" phx-value-candidate_id={@selected_candidate.id}>
            Generate article suggestion
          </button>

          <h3>Retrieval evidence</h3>
          <%= if @selected_candidate.retrieval_gap_events == [] do %>
            <p>No retrieval evidence linked.</p>
          <% else %>
            <ul>
              <%= for event <- @selected_candidate.retrieval_gap_events do %>
                <li>
                  <strong><%= GapCandidatePresenter.event_reason_label(event.reason) %></strong>
                  <div><%= GapCandidatePresenter.surface_label(event.surface) %></div>
                  <div><%= event.canonical_hit_count %> canonical / <%= event.assistive_hit_count %> assistive hits</div>
                  <div><%= event.sanitized_query_excerpt %></div>
                </li>
              <% end %>
            </ul>
          <% end %>

          <h3>Similar resolved cases</h3>
          <%= if @selected_candidate.manual_handling_evidence == [] do %>
            <p>No repeated manual-handling evidence linked.</p>
          <% else %>
            <ul>
              <%= for evidence <- @selected_candidate.manual_handling_evidence do %>
                <li>
                  <strong><%= evidence.issue_summary %></strong>
                  <div><%= evidence.resolution_note %></div>
                  <div><%= Enum.join(evidence.actions_taken || [], ", ") %></div>
                  <%= if GapCandidatePresenter.conversation_target(evidence) do %>
                    <.link navigate={GapCandidatePresenter.conversation_target(evidence)}>Open conversation</.link>
                  <% end %>
                </li>
              <% end %>
            </ul>
          <% end %>
        </section>
      <% end %>
    </div>
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
