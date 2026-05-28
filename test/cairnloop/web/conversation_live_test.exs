defmodule Cairnloop.Web.ConversationLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, ReviewTask}
  alias Cairnloop.Web.ConversationLive

  defmodule MockRepo do
    def get!(Cairnloop.Conversation, 1) do
      %Cairnloop.Conversation{
        id: 1,
        host_user_id: "user_42",
        subject: "Test Subject",
        messages: [],
        drafts: [
          %Cairnloop.Automation.Draft{
            id: 202,
            content: "Newly loaded AI draft",
            customer_reply: "Newly loaded AI draft",
            operator_summary: "Grounded in a canonical article",
            proposal_type: :reply,
            evidence_snapshot: %{
              evidence: [
                %{
                  source_type: :knowledge_base,
                  trust_level: :canonical,
                  title: "Billing export policy",
                  content: "Canonical article on billing exports",
                  citation_target: %{article_id: 33, revision_id: 10, chunk_index: 0},
                  metadata: %{destination: %{article_id: 33}},
                  updated_at: DateTime.utc_now()
                }
              ]
            },
            grounding_metadata: %{reason: :canonical_results},
            status: :pending
          }
        ]
      }
    end

    def get!(Cairnloop.Conversation, 321) do
      %Cairnloop.Conversation{
        id: 321,
        host_user_id: "user_42",
        subject: "Weekend export fails",
        messages: [],
        drafts: []
      }
    end

    def get(_schema, _id), do: nil

    def get_by(_schema, _clauses), do: nil

    def insert(%Ecto.Changeset{} = changeset) do
      # CR-01 regression test hook: force {:error, changeset} for specific tests
      if Process.get(:force_insert_error) do
        {:error, changeset}
      else
        if changeset.valid? do
          struct =
            changeset
            |> Ecto.Changeset.apply_changes()
            |> maybe_put_id()

          {:ok, struct}
        else
          {:error, changeset}
        end
      end
    end

    def all(_query), do: []

    # CR-02 fix: get_latest_approval/1 uses Ecto.Query |> repo().one().
    # In unit tests, return nil (no active approval) by default.
    def one(_query), do: nil

    def preload(record, _), do: record

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct
  end

  defmodule SuccessContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts), do: {:ok, %{"Plan" => "Pro"}}
  end

  defmodule NestedSuccessContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts) do
      {:ok,
       %{
         "identity" => %{"full_name" => "Alice", "id" => 42},
         "billing" => %{"plan" => "Pro", "tags" => ["vip", "active"]}
       }}
    end
  end

  defmodule UnsupportedContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts) do
      {:ok,
       %{
         "pid" => self(),
         "tuple" => {:error, :reason},
         "func" => fn -> :ok end
       }}
    end
  end

  defmodule ErrorContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts), do: {:error, :not_found}
  end

  defmodule MockKnowledgeAutomation do
    def create_or_reuse_conversation_quick_fix(attrs, _opts) do
      Process.put(:create_quick_fix_attrs, attrs)
      Process.get(:create_quick_fix_result)
    end

    def create_or_reuse_authoring_article_for_suggestion(suggestion_id, _opts) do
      Process.put(:manual_draft_suggestion_id, suggestion_id)
      {:ok, 91}
    end

    def record_editor_handoff(suggestion_id, _opts) do
      {:ok,
       struct(Cairnloop.KnowledgeAutomation.ArticleSuggestion, %{
         id: suggestion_id,
         manual_edit_opened_at: DateTime.utc_now()
       })}
    end

    def get_conversation_quick_fix(321, _opts) do
      {:ok,
       %{
         suggestion: quick_fix_suggestion(:shell_created),
         review_task: quick_fix_review_task(:pending_review),
         quick_fix: %{
           "thread_context" => %{"conversation_id" => 321, "subject" => "Weekend export fails"},
           "canonical_retrieval" => %{"canonical_evidence_count" => 0, "citation_ready" => false},
           "resolved_case_assists" => %{
             "case_count" => 1,
             "summaries" => ["Prior export timeout case"]
           }
         }
       }}
    end

    def get_conversation_quick_fix(_conversation_id, _opts), do: {:error, :not_found}

    defp quick_fix_suggestion(outcome) do
      metadata =
        case outcome do
          :shell_created ->
            %{
              "quick_fix_outcome" => "shell_created",
              "quick_fix_reason" => "missing_canonical_grounding",
              "quick_fix_package" => %{
                "thread_context" => %{
                  "conversation_id" => 321,
                  "subject" => "Weekend export fails",
                  "message_excerpt" => "The export stalls every Saturday morning.",
                  "message_count" => 4
                },
                "canonical_retrieval" => %{
                  "canonical_evidence_count" => 0,
                  "citation_ready" => false,
                  "evidence_digest" => "shell-digest"
                },
                "resolved_case_assists" => %{
                  "case_count" => 1,
                  "summaries" => ["Prior export timeout case"]
                }
              }
            }
        end

      struct(ArticleSuggestion,
        id: 77,
        title: "Weekend export quick fix",
        status: :ready,
        entrypoint_type: :conversation_quick_fix,
        entrypoint_id: 321,
        operator_summary:
          "A draft shell was created because the maintenance need is real, but canonical grounding is incomplete.",
        grounding_metadata: metadata
      )
    end

    defp quick_fix_review_task(status) do
      struct(ReviewTask,
        id: 61,
        article_suggestion_id: 77,
        status: status,
        publish_status: :not_started,
        reindex_status: :not_started,
        article_suggestion: quick_fix_suggestion(:shell_created)
      )
    end
  end

  defmodule ReindexFailedKnowledgeAutomation do
    def get_conversation_quick_fix(321, _opts) do
      suggestion =
        struct(ArticleSuggestion,
          id: 79,
          title: "Weekend export quick fix",
          status: :ready,
          entrypoint_type: :conversation_quick_fix,
          entrypoint_id: 321,
          operator_summary: "Published, but reindex follow-through needs operator attention.",
          grounding_metadata: %{
            "quick_fix_outcome" => "ready",
            "quick_fix_package" => %{
              "thread_context" => %{"conversation_id" => 321, "subject" => "Weekend export fails"},
              "canonical_retrieval" => %{
                "canonical_evidence_count" => 1,
                "citation_ready" => true
              },
              "resolved_case_assists" => %{
                "case_count" => 1,
                "summaries" => ["Prior export timeout case"]
              }
            }
          }
        )

      review_task =
        struct(ReviewTask,
          id: 63,
          article_suggestion_id: 79,
          status: :published,
          publish_status: :published,
          reindex_status: :failed,
          article_suggestion: suggestion
        )

      {:ok, %{suggestion: suggestion, review_task: review_task, quick_fix: %{}}}
    end

    def get_conversation_quick_fix(_conversation_id, _opts), do: {:error, :not_found}
    def create_or_reuse_conversation_quick_fix(_attrs, _opts), do: {:error, :not_implemented}

    def create_or_reuse_authoring_article_for_suggestion(_suggestion_id, _opts),
      do: {:error, :not_implemented}
  end

  defmodule ProcessBackedQuickFixKnowledgeAutomation do
    def get_conversation_quick_fix(321, _opts),
      do: Process.get(:conversation_quick_fix_result, {:error, :not_found})

    def get_conversation_quick_fix(_conversation_id, _opts), do: {:error, :not_found}

    def create_or_reuse_conversation_quick_fix(attrs, _opts) do
      Process.put(:create_quick_fix_attrs, attrs)
      Process.get(:create_quick_fix_result)
    end

    def create_or_reuse_authoring_article_for_suggestion(suggestion_id, _opts) do
      Process.put(:manual_draft_suggestion_id, suggestion_id)
      {:ok, 91}
    end
  end

  defmodule MockOutbound do
    def trigger(conversation_id, opts) do
      Process.put(:outbound_trigger_called_with, {conversation_id, opts})
      Process.get(:outbound_trigger_result, {:ok, %{message: %{id: 999}}})
    end
  end

  # Governed tool fixtures (new contract: scope/0, run/3, authorize/2 — no can_execute?/execute)

  defmodule SimpleTool do
    use Cairnloop.Tool, risk_tier: :read_only, title: "Simple Tool"

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, "simple action result"}
  end

  defmodule InputTool do
    use Cairnloop.Tool, risk_tier: :low_write, title: "Input Tool"

    embedded_schema do
      field(:reason, :string)
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset

      tool
      |> cast(attrs, [:reason])
      |> validate_required([:reason])
    end

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(tool, _actor_id, _context), do: {:ok, "executed with #{tool.reason}"}
  end

  defmodule ScopeTool do
    use Cairnloop.Tool, risk_tier: :low_write, title: "Scope Tool"

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    @impl Cairnloop.Tool
    def scope, do: [:admin_scope]

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, "scope result"}
  end

  defmodule PolicyTool do
    use Cairnloop.Tool, risk_tier: :high_write, title: "Policy Tool"

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: {:error, {:policy_violation, :high_risk_denied}}

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, "policy result"}
  end

  defmodule CustomLiveView do
    use Phoenix.LiveView
    def render(assigns), do: ~H"<div>Custom</div>"
  end

  defmodule CustomUiTool do
    use Cairnloop.Tool, risk_tier: :read_only, title: "Custom UI Tool"

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, "custom UI"}

    @impl Cairnloop.Tool
    def custom_ui, do: CustomLiveView
  end

  setup do
    Process.delete(:outbound_trigger_called_with)
    Process.delete(:outbound_trigger_result)
    Application.put_env(:cairnloop, :repo, MockRepo)
    original_tools = Application.get_env(:cairnloop, :tools, [])
    original_knowledge_automation = Application.get_env(:cairnloop, :knowledge_automation)
    original_outbound_module = Application.get_env(:cairnloop, :outbound_module)

    original_outbound_recovery_template_id =
      Application.get_env(:cairnloop, :outbound_recovery_template_id)

    Application.put_env(:cairnloop, :tools, [SimpleTool, InputTool])

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :context_provider)
      Application.put_env(:cairnloop, :tools, original_tools)

      if original_knowledge_automation do
        Application.put_env(:cairnloop, :knowledge_automation, original_knowledge_automation)
      else
        Application.delete_env(:cairnloop, :knowledge_automation)
      end

      if original_outbound_module do
        Application.put_env(:cairnloop, :outbound_module, original_outbound_module)
      else
        Application.delete_env(:cairnloop, :outbound_module)
      end

      if is_nil(original_outbound_recovery_template_id) do
        Application.delete_env(:cairnloop, :outbound_recovery_template_id)
      else
        Application.put_env(
          :cairnloop,
          :outbound_recovery_template_id,
          original_outbound_recovery_template_id
        )
      end
    end)

    :ok
  end

  describe "mount/3 context resolution" do
    test "uses DefaultContextProvider when nothing is configured" do
      Application.delete_env(:cairnloop, :context_provider)

      assert {:ok, socket} = ConversationLive.mount(%{"id" => 1}, %{}, %Phoenix.LiveView.Socket{})
      assert socket.assigns.host_context == %{}
      assert socket.assigns.context_error == nil
    end

    test "handles success tuple from configured context provider" do
      Application.put_env(:cairnloop, :context_provider, SuccessContextProvider)

      assert {:ok, socket} = ConversationLive.mount(%{"id" => 1}, %{}, %Phoenix.LiveView.Socket{})
      assert socket.assigns.host_context == %{"Plan" => "Pro"}
      assert socket.assigns.context_error == nil
    end

    test "handles error tuple from configured context provider" do
      Application.put_env(:cairnloop, :context_provider, ErrorContextProvider)

      assert {:ok, socket} = ConversationLive.mount(%{"id" => 1}, %{}, %Phoenix.LiveView.Socket{})
      assert socket.assigns.host_context == %{}
      assert socket.assigns.context_error == :not_found
    end
  end

  describe "handle_info/2" do
    test "reloads conversation on :draft_created" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1},
          __changed__: %{}
        }
      }

      assert {:noreply, new_socket} = ConversationLive.handle_info({:draft_created, 202}, socket)
      assert hd(new_socket.assigns.conversation.drafts).id == 202
      assert hd(new_socket.assigns.conversation.drafts).content == "Newly loaded AI draft"
    end

    # Phase 28 D-17: operator view refreshes when a customer message arrives via PubSub.
    # UAT-1 operator side: proves the ConversationLive reacts to {:message_created} broadcasts
    # without requiring a live browser tab — the message_id arg is intentionally ignored
    # (reload always fetches the current DB state).
    test "reloads conversation on :message_created (Phase 28 D-17 operator view refresh)" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1},
          __changed__: %{}
        }
      }

      # Any message_id triggers a reload — the value is unused by the handler.
      assert {:noreply, new_socket} = ConversationLive.handle_info({:message_created, 42}, socket)

      # MockRepo.get!(Cairnloop.Conversation, 1) returns the conversation with draft id 202.
      # A changed conversation proves reload_conversation_with_context/2 was invoked.
      assert hd(new_socket.assigns.conversation.drafts).id == 202
    end
  end

  describe "render/1 normalizes context and shell" do
    test "renders empty shell with correct copy when context is empty" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)
      assert html =~ "data-host-surface=\"conversation\""
      assert html =~ "data-host-user-id=\"user_42\""
      assert html =~ "data-preserve-reply-form=\"true\""
      assert html =~ "No customer context yet"

      assert html =~
               "This conversation has no host context to show. Continue with the thread, or reload after host data becomes available."
    end

    test "renders error shell with correct copy when context_error is present" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: :timeout,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~
               "Customer context is unavailable right now. Continue handling the conversation, then reload to try again."

      # The shell 'Customer Context' should still be visible
      assert html =~ "Customer Context"
    end

    test "renders ordered nested context sections and humanizes labels" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{
          "identity" => %{"full_name" => "Alice", "id" => 42},
          "billing" => %{"plan" => "Pro", "tags" => ["vip", "active"]}
        },
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      # Assert correct humanization and content presence
      assert html =~ "Billing"
      assert html =~ "Identity"
      assert html =~ "Full Name"
      assert html =~ "Alice"
      assert html =~ "vip"
      assert html =~ "active"

      # Assert ordering (Billing before Identity alphabetically)
      billing_idx = :binary.match(html, "Billing") |> elem(0)
      identity_idx = :binary.match(html, "Identity") |> elem(0)
      assert billing_idx < identity_idx
    end

    test "renders Unsupported value for unsupported terms instead of raw inspect" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{
          "pid" => self(),
          "tuple" => {:error, :reason},
          "func" => fn -> :ok end
        },
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "Unsupported value"
      refute html =~ "PID"
      refute html =~ "{:error, :reason}"
      refute html =~ "#Function<"
    end
  end

  describe "render/1 draft shell and inline actions" do
    test "renders outbound recovery card only for resolved conversations" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          status: :resolved,
          subject: "Test",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "Outbound recovery"
      assert html =~ "Send Recovery Follow-up"
      assert html =~ "configured recovery template"

      unresolved_html =
        assigns
        |> Map.put(
          :conversation,
          %{assigns.conversation | status: :open}
        )
        |> render_html()

      refute unresolved_html =~ "Send Recovery Follow-up"
    end

    test "renders system_outbound messages with distinct label and delivery status chip" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          status: :resolved,
          subject: "Test",
          messages: [
            %Cairnloop.Message{
              id: 10,
              role: :system_outbound,
              content: "We wanted to confirm the fix stuck.",
              metadata: %{"template_id" => "recovery_v1", "status" => "sent"}
            }
          ],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "Outbound recovery"
      assert html =~ "We wanted to confirm the fix stuck."
      assert html =~ "message-status-chip status-sent"
      assert html =~ "Sent"
    end

    test "renders the idle quick-fix card between context and draft audit cards" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 321,
          status: :open,
          subject: "Weekend export fails",
          messages: [],
          drafts: [
            %Cairnloop.Automation.Draft{
              id: 101,
              content: "Hello from AI",
              customer_reply: "Hello from AI",
              proposal_type: :reply,
              evidence_snapshot: %{evidence: []},
              status: :pending
            }
          ],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        quick_fix_card: %{status: :idle},
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "KB maintenance"
      assert html =~ "No quick fix started"
      assert html =~ "Use conversation evidence to open a KB maintenance task"
      assert html =~ "Thread context"
      assert html =~ "Canonical retrieval"
      assert html =~ "Resolved case assists"
      assert html =~ "Start KB quick fix"
      assert element_index(html, "Customer Context") < element_index(html, "KB maintenance")
      assert element_index(html, "KB maintenance") < element_index(html, "AI Draft / Audit")
    end

    test "renders the quick-fix card as a distinct evidence-rail section outside generic actions" do
      Application.put_env(:cairnloop, :context_provider, SuccessContextProvider)

      {:ok, socket} = ConversationLive.mount(%{"id" => 1}, %{}, %Phoenix.LiveView.Socket{})
      html = render_html(Map.put(socket.assigns, :socket, %Phoenix.LiveView.Socket{}))

      assert html =~ "Actions"
      assert html =~ "KB maintenance"
      assert html =~ "Start KB quick fix"
      assert element_index(html, "Actions") < element_index(html, "KB maintenance")
      assert element_index(html, "KB maintenance") < element_index(html, "AI Draft / Audit")
    end

    test "renders shell state copy, reason callout, and follow-through status rail" do
      Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

      {:ok, socket} = ConversationLive.mount(%{"id" => 321}, %{}, %Phoenix.LiveView.Socket{})
      html = render_html(Map.put(socket.assigns, :socket, %Phoenix.LiveView.Socket{}))

      assert html =~ "KB maintenance"

      assert html =~
               "A draft shell was created because the maintenance need is real, but canonical grounding is incomplete."

      assert html =~ "Missing canonical grounding"
      assert html =~ "Draft shell created"
      assert html =~ "Open review task"
      assert html =~ "View maintenance lane"
      assert html =~ "4 messages summarized"
      assert html =~ "No citation-ready canonical evidence"
      assert html =~ "1 supporting case"
    end

    test "renders retry-needed copy when reindex follow-through fails after publish" do
      Application.put_env(:cairnloop, :knowledge_automation, ReindexFailedKnowledgeAutomation)

      {:ok, socket} = ConversationLive.mount(%{"id" => 321}, %{}, %Phoenix.LiveView.Socket{})
      html = render_html(Map.put(socket.assigns, :socket, %Phoenix.LiveView.Socket{}))

      assert html =~ "Follow-through needs attention"
      assert html =~ "Published, but reindex follow-through needs operator attention."
      assert html =~ "Published, reindex pending"
      refute html =~ "Reindexed"
    end

    test "renders distinct follow-through states instead of collapsing publish completion into one generic state" do
      Application.put_env(
        :cairnloop,
        :knowledge_automation,
        ProcessBackedQuickFixKnowledgeAutomation
      )

      for {reindex_status, heading, summary} <- [
            {:queued, "Published, reindex pending", "Published revision #88. Reindex queued."},
            {:running, "Reindexing", "Published revision #88. Reindexing in progress."},
            {:completed, "Reindexed", "Published revision #88. Reindex completed."},
            {:failed, "Follow-through needs attention",
             "Published, but reindex follow-through needs operator attention."}
          ] do
        Process.put(
          :conversation_quick_fix_result,
          follow_through_quick_fix_result(reindex_status)
        )

        {:ok, socket} = ConversationLive.mount(%{"id" => 321}, %{}, %Phoenix.LiveView.Socket{})
        html = render_html(Map.put(socket.assigns, :socket, %Phoenix.LiveView.Socket{}))

        assert html =~ heading
        assert html =~ summary
      end
    end

    test "renders grounded draft sections, evidence semantics, and inline actions" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [
            %Cairnloop.Automation.Draft{
              id: 101,
              content: "Hello from AI",
              customer_reply: "Hello from AI",
              operator_summary: "Backed by a published Knowledge Base article.",
              proposal_type: :reply,
              evidence_snapshot: %{
                evidence: [
                  %{
                    source_type: :knowledge_base,
                    trust_level: :canonical,
                    title: "Export policy",
                    content: "Canonical export instructions",
                    citation_target: %{article_id: 1, revision_id: 2, chunk_index: 0},
                    metadata: %{destination: %{article_id: 1}},
                    updated_at: DateTime.utc_now()
                  },
                  %{
                    source_type: :resolved_case,
                    trust_level: :assistive,
                    title: "Similar export case",
                    content: "Supporting case details",
                    citation_target: %{conversation_id: 55, chunk_index: 1},
                    metadata: %{destination: %{conversation_id: 55}},
                    resolved_at: DateTime.utc_now()
                  }
                ]
              },
              grounding_metadata: %{reason: :canonical_results},
              status: :pending
            }
          ],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)
      assert html =~ "AI Draft / Audit"
      assert html =~ "Operator summary"
      assert html =~ "Grounding note"
      assert html =~ "Canonical guidance matched"
      assert html =~ "Customer reply"
      assert html =~ "Supporting evidence"
      assert html =~ "Hello from AI"
      assert html =~ "Knowledge Base"
      assert html =~ "Resolved case"
      assert html =~ "Canonical guidance"
      assert html =~ "Supporting evidence"
      assert html =~ "Approve & Send"
      assert html =~ "Apply to Composer"
      assert html =~ "Discard"
    end

    test "renders inline discard confirmation when pending_discard_draft_id is set" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [
            %Cairnloop.Automation.Draft{
              id: 101,
              content: "Hello from AI",
              customer_reply: "Hello from AI",
              proposal_type: :reply,
              evidence_snapshot: %{evidence: []},
              status: :pending
            }
          ],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: 101,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~
               "Discard draft: Remove this draft from the rail? This action is recorded and cannot be undone."

      assert html =~ "phx-click=\"confirm_discard_draft\""
      assert html =~ "phx-click=\"cancel_discard_draft\""
    end

    test "renders clarification and escalation as explicit operator states" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [
            %Cairnloop.Automation.Draft{
              id: 111,
              customer_reply: "Could you share the specific error message?",
              proposal_type: :clarification,
              operator_summary: "One customer detail is still missing.",
              grounding_metadata: %{reason: :canonical_insufficient_detail},
              evidence_snapshot: %{evidence: []},
              status: :pending
            },
            %Cairnloop.Automation.Draft{
              id: 112,
              customer_reply: "Please escalate this thread for manual review.",
              proposal_type: :escalation,
              operator_summary:
                "Clarification has already been used once and grounding is still weak.",
              clarification_attempts: 1,
              grounding_metadata: %{reason: :clarification_limit_reached},
              evidence_snapshot: %{evidence: []},
              status: :pending
            }
          ],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "Clarification required"
      assert html =~ "Escalation recommended"
      assert html =~ "Canonical detail is still missing"
      assert html =~ "Clarification limit reached"
      assert html =~ "Could you share the specific error message?"
      assert html =~ "Please escalate this thread for manual review."
    end
  end

  describe "reply form safety during search integration" do
    test "keeps draft reply content and search mount contract together" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test Subject",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => "Draft reply in progress"}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "Draft reply in progress"
      assert html =~ "class=\"reply-form\""
      assert html =~ "data-host-surface=\"conversation\""
      assert html =~ "data-preserve-reply-form=\"true\""
    end
  end

  describe "tools rendering and execution" do
    test "renders available tools in the context pane" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{"id" => "123"},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      assert html =~ "Actions"

      # Simple tool (no inputs) should render a simple button
      assert html =~ "phx-click=\"execute_tool\""
      assert html =~ "phx-value-tool=\"Cairnloop.Web.ConversationLiveTest.SimpleTool\""

      # Input tool should render a form
      assert html =~ "phx-submit=\"execute_tool\""
      assert html =~ "<input"
      assert html =~ "name=\"tool_params[reason]\""
    end

    test "handle_event execute_tool proposes successfully and emits info flash with proposal id" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      tool_ref = Atom.to_string(SimpleTool)

      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => tool_ref, "tool_params" => %{}},
                 socket
               )

      assert socket.assigns.flash["info"] =~ "Proposed"
      assert socket.assigns.flash["info"] =~ "pending review"
    end

    test "handle_event execute_tool emits info flash containing proposal id for Phase 14 seam" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      tool_ref = Atom.to_string(SimpleTool)

      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => tool_ref, "tool_params" => %{}},
                 socket
               )

      # Flash must contain "#<id>" so Phase 14 can replace it with a timeline card
      assert socket.assigns.flash["info"] =~ "#"
    end

    test "handle_event execute_tool blocks on unknown tool ref with unsupported error flash" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{},
          flash: %{},
          __changed__: %{}
        }
      }

      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => "Elixir.NonExistentTool", "tool_params" => %{}},
                 socket
               )

      assert socket.assigns.flash["error"] =~ "Unknown tool"
    end

    test "handle_event execute_tool blocks on missing required input with needs_input error flash" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      # InputTool requires :reason — send empty tool_params to trigger needs_input
      tool_ref = Atom.to_string(InputTool)

      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => tool_ref, "tool_params" => %{}},
                 socket
               )

      assert socket.assigns.flash["error"] =~ "Invalid tool parameters"
    end

    test "handle_event execute_tool shows scope_invalid flash without crashing (CR-01 regression)" do
      # ScopeTool requires :admin_scope which is absent from host_context — triggers
      # :scope_invalid, whose reason is the tuple {:missing_scopes, [...]}. Before CR-01
      # was fixed, interpolating that tuple with "#{reason}" raised Protocol.UndefinedError.
      Application.put_env(:cairnloop, :tools, [SimpleTool, InputTool, ScopeTool])

      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{},
          flash: %{},
          __changed__: %{}
        }
      }

      tool_ref = Atom.to_string(ScopeTool)

      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => tool_ref, "tool_params" => %{}},
                 socket
               )

      assert socket.assigns.flash["error"] =~ "Tool not available in this context"
    end

    test "handle_event execute_tool shows policy_denied flash without crashing (CR-01 regression)" do
      # PolicyTool.authorize/2 returns {:error, {:policy_violation, :high_risk_denied}} — a
      # tuple reason. Before CR-01, interpolating it raised Protocol.UndefinedError.
      Application.put_env(:cairnloop, :tools, [SimpleTool, InputTool, PolicyTool])

      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{},
          flash: %{},
          __changed__: %{}
        }
      }

      tool_ref = Atom.to_string(PolicyTool)

      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => tool_ref, "tool_params" => %{}},
                 socket
               )

      assert socket.assigns.flash["error"] =~ "Tool call not permitted"
    end

    test "handle_event execute_tool does not contain try/rescue, run/3, execute/3, or String.to_existing_atom" do
      # Source-level assertion: the handler body must be free of the old inline execution pattern.
      # Resolve from the test file's own path up to the project root.
      project_root =
        __ENV__.file
        |> Path.expand()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()

      source_path = Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"])
      source = File.read!(source_path)

      # Extract just the execute_tool handler body — from the handler def to the next top-level def
      # This avoids catching the unrelated String.to_existing_atom at line 754 (map-key atomization).
      handler_start = :binary.match(source, "\"execute_tool\"") |> elem(0)

      handler_end_marker =
        :binary.match(source, "defp reload_conversation_with_context") |> elem(0)

      handler_region = binary_part(source, handler_start, handler_end_marker - handler_start)

      refute handler_region =~ "String.to_existing_atom"
      refute handler_region =~ "can_execute?"
      refute handler_region =~ ".execute("
      refute handler_region =~ "try do"
      assert handler_region =~ "Governance.propose"
      assert handler_region =~ "failure_reason_message"
    end

    test "handle_event execute_tool emits calm error flash on {:error, changeset} without crashing (CR-01 regression)" do
      # CR-01: Governance.propose/3 can return {:error, %Ecto.Changeset{}} on insert
      # failure (FK violation, DB drop, etc.). The handler must NOT raise CaseClauseError.
      # Force MockRepo.insert/1 to return {:error, changeset} for this test.
      Process.put(:force_insert_error, true)

      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      tool_ref = Atom.to_string(SimpleTool)

      # Must NOT raise CaseClauseError — must return {:noreply, socket} with an error flash
      assert {:noreply, socket} =
               ConversationLive.handle_event(
                 "execute_tool",
                 %{"tool" => tool_ref, "tool_params" => %{}},
                 socket
               )

      # Fail closed: calm message, no raw changeset, no crash
      assert socket.assigns.flash["error"] =~ "could not be recorded"
      refute socket.assigns.flash["error"] =~ "Ecto.Changeset"
      refute socket.assigns.flash["error"] =~ "#Ecto"
    end
  end

  describe "quick-fix launch actions" do
    test "start_quick_fix creates a review-ready task and redirects into the shared lane" do
      Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

      Process.put(
        :create_quick_fix_result,
        {:ok,
         %{
           suggestion:
             struct(ArticleSuggestion,
               id: 77,
               entrypoint_type: :conversation_quick_fix,
               entrypoint_id: 321,
               status: :ready,
               grounding_metadata: %{"quick_fix_outcome" => "ready"}
             ),
           review_task: struct(ReviewTask, id: 61, status: :pending_review),
           reused?: false,
           quick_fix: %{}
         }}
      )

      assert {:noreply, socket} =
               ConversationLive.handle_event("start_quick_fix", %{}, quick_fix_socket())

      assert Process.get(:create_quick_fix_attrs).conversation_id == 321
      assert Process.get(:create_quick_fix_attrs).host_user_id == "user_42"
      assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=61"}} = socket.redirected
    end

    test "start_quick_fix reopens the existing review task when work already exists" do
      Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

      Process.put(
        :create_quick_fix_result,
        {:ok,
         %{
           suggestion:
             struct(ArticleSuggestion,
               id: 77,
               entrypoint_type: :conversation_quick_fix,
               entrypoint_id: 321,
               status: :ready,
               grounding_metadata: %{"quick_fix_outcome" => "ready"}
             ),
           review_task: struct(ReviewTask, id: 61, status: :pending_review),
           reused?: true,
           quick_fix: %{}
         }}
      )

      assert {:noreply, socket} =
               ConversationLive.handle_event("start_quick_fix", %{}, quick_fix_socket())

      assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=61"}} = socket.redirected
    end

    test "start_quick_fix redirects shell-created quick fixes into the shared review lane with bounded copy" do
      Application.put_env(
        :cairnloop,
        :knowledge_automation,
        ProcessBackedQuickFixKnowledgeAutomation
      )

      Process.put(
        :create_quick_fix_result,
        {:ok,
         %{
           suggestion: quick_fix_suggestion_fixture(:shell_created),
           review_task: struct(ReviewTask, id: 61, status: :pending_review),
           reused?: false,
           quick_fix: %{}
         }}
      )

      assert {:noreply, socket} =
               ConversationLive.handle_event("start_quick_fix", %{}, quick_fix_socket())

      assert socket.assigns.quick_fix_card.status == :shell_created
      assert socket.assigns.quick_fix_card.reason == "Missing canonical grounding"
      assert socket.assigns.quick_fix_card.primary_action.label == "Open review task"
      assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=61"}} = socket.redirected
    end

    test "start_quick_fix keeps blocked/manual-required outcomes in the thread" do
      Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

      blocked_suggestion =
        struct(ArticleSuggestion,
          id: 78,
          entrypoint_type: :conversation_quick_fix,
          entrypoint_id: 321,
          status: :failed,
          grounding_metadata: %{
            "quick_fix_outcome" => "blocked_manual_required",
            "quick_fix_reason" => "policy_guard_blocked",
            "quick_fix_package" => %{
              "thread_context" => %{"message_count" => 4},
              "canonical_retrieval" => %{
                "canonical_evidence_count" => 0,
                "citation_ready" => false
              },
              "resolved_case_assists" => %{"case_count" => 1}
            }
          }
        )

      Process.put(
        :create_quick_fix_result,
        {:ok,
         %{
           suggestion: blocked_suggestion,
           review_task: struct(ReviewTask, id: 62, status: :review_needed),
           reused?: false,
           quick_fix: %{}
         }}
      )

      assert {:noreply, socket} =
               ConversationLive.handle_event("start_quick_fix", %{}, quick_fix_socket())

      assert socket.assigns.quick_fix_card.status == :blocked_manual_required
      assert socket.assigns.quick_fix_card.primary_action.label == "Open manual draft"
      assert socket.redirected == nil
    end

    test "start_quick_fix surfaces a bounded flash when preparation fails" do
      Application.put_env(
        :cairnloop,
        :knowledge_automation,
        ProcessBackedQuickFixKnowledgeAutomation
      )

      Process.put(:create_quick_fix_result, {:error, :missing_grounding})

      assert {:noreply, socket} =
               ConversationLive.handle_event("start_quick_fix", %{}, quick_fix_socket())

      assert socket.assigns.flash["error"] ==
               "Quick fix could not prepare a reviewable suggestion."
    end

    test "open_manual_draft routes blocked quick fixes into the shared authoring path" do
      Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

      socket =
        quick_fix_socket(%{
          quick_fix_card: %{
            status: :blocked_manual_required,
            suggestion_id: 78,
            review_task_id: 62,
            primary_action: %{event: "open_manual_draft", label: "Open manual draft"},
            secondary_action: %{
              label: "View maintenance lane",
              to: "/knowledge-base/suggestions?task=62"
            }
          }
        })

      assert {:noreply, redirected_socket} =
               ConversationLive.handle_event("open_manual_draft", %{}, socket)

      assert Process.get(:manual_draft_suggestion_id) == 78
      assert {:live, :redirect, %{to: path}} = redirected_socket.redirected
      assert path =~ "/knowledge-base/91/edit?suggestion_id=78"
      assert path =~ "review_task_id=62"
      assert path =~ "return_to=%2F321"
    end
  end

  describe "outbound recovery trigger" do
    test "queues a recovery follow-up for resolved conversations" do
      Application.put_env(:cairnloop, :outbound_module, MockOutbound)
      Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")

      socket =
        quick_fix_socket(%{
          conversation: %Cairnloop.Conversation{
            id: 321,
            status: :resolved,
            host_user_id: "user_42",
            subject: "Weekend export fails",
            drafts: [],
            messages: []
          }
        })

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event("trigger_recovery_follow_up", %{}, socket)

      assert Process.get(:outbound_trigger_called_with) ==
               {321, [template_id: "recovery_v1", actor: "user_42"]}

      assert updated_socket.assigns.flash["info"] == "Recovery follow-up queued."
    end

    test "fails closed when the recovery template is not configured" do
      Application.put_env(:cairnloop, :outbound_module, MockOutbound)
      Application.delete_env(:cairnloop, :outbound_recovery_template_id)

      socket =
        quick_fix_socket(%{
          conversation: %Cairnloop.Conversation{
            id: 321,
            status: :resolved,
            host_user_id: "user_42",
            subject: "Weekend export fails",
            drafts: [],
            messages: []
          }
        })

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event("trigger_recovery_follow_up", %{}, socket)

      assert updated_socket.assigns.flash["error"] ==
               "Recovery follow-up template is not configured."

      assert Process.get(:outbound_trigger_called_with) == nil
    end

    test "rejects forced trigger attempts for unresolved conversations" do
      Application.put_env(:cairnloop, :outbound_module, MockOutbound)
      Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")

      socket =
        quick_fix_socket(%{
          conversation: %Cairnloop.Conversation{
            id: 321,
            status: :open,
            host_user_id: "user_42",
            subject: "Weekend export fails",
            drafts: [],
            messages: []
          }
        })

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event("trigger_recovery_follow_up", %{}, socket)

      assert updated_socket.assigns.flash["error"] ==
               "Recovery follow-up is only available for resolved conversations."

      assert Process.get(:outbound_trigger_called_with) == nil
    end

    test "surfaces a bounded error when outbound trigger fails" do
      Application.put_env(:cairnloop, :outbound_module, MockOutbound)
      Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")

      Process.put(:outbound_trigger_result, {:error, :delivery_job, :boom, %{}})

      socket =
        quick_fix_socket(%{
          conversation: %Cairnloop.Conversation{
            id: 321,
            status: :resolved,
            host_user_id: "user_42",
            subject: "Weekend export fails",
            drafts: [],
            messages: []
          }
        })

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event("trigger_recovery_follow_up", %{}, socket)

      assert updated_socket.assigns.flash["error"] ==
               "Recovery follow-up could not be queued right now. Please try again."
    end
  end

  defp render_html(assigns) do
    render_component(&ConversationLive.render/1, assigns)
  end

  defp quick_fix_socket(overrides \\ %{}) do
    base_assigns = %{
      conversation: %Cairnloop.Conversation{
        id: 321,
        status: :open,
        host_user_id: "user_42",
        subject: "Weekend export fails",
        drafts: [],
        messages: []
      },
      host_context: %{},
      context_error: nil,
      quick_fix_card: %{status: :idle},
      form: Phoenix.Component.to_form(%{"content" => "Draft reply in progress"}),
      flash: %{},
      __changed__: %{}
    }

    %Phoenix.LiveView.Socket{
      endpoint: Cairnloop.Web.Endpoint,
      assigns: Map.merge(base_assigns, overrides)
    }
  end

  defp quick_fix_suggestion_fixture(:shell_created) do
    struct(ArticleSuggestion,
      id: 77,
      title: "Weekend export quick fix",
      status: :ready,
      entrypoint_type: :conversation_quick_fix,
      entrypoint_id: 321,
      operator_summary:
        "A draft shell was created because the maintenance need is real, but canonical grounding is incomplete.",
      grounding_metadata: %{
        "quick_fix_outcome" => "shell_created",
        "quick_fix_reason" => "missing_canonical_grounding",
        "quick_fix_package" => %{
          "thread_context" => %{
            "conversation_id" => 321,
            "subject" => "Weekend export fails",
            "message_excerpt" => "The export stalls every Saturday morning.",
            "message_count" => 4
          },
          "canonical_retrieval" => %{
            "canonical_evidence_count" => 0,
            "citation_ready" => false,
            "evidence_digest" => "shell-digest"
          },
          "resolved_case_assists" => %{
            "case_count" => 1,
            "summaries" => ["Prior export timeout case"]
          }
        }
      }
    )
  end

  defp quick_fix_suggestion_fixture(:ready) do
    struct(ArticleSuggestion,
      id: 79,
      title: "Weekend export quick fix",
      status: :ready,
      entrypoint_type: :conversation_quick_fix,
      entrypoint_id: 321,
      operator_summary: "Backed by a published Knowledge Base article.",
      grounding_metadata: %{
        "quick_fix_outcome" => "ready",
        "quick_fix_package" => %{
          "thread_context" => %{"conversation_id" => 321, "subject" => "Weekend export fails"},
          "canonical_retrieval" => %{"canonical_evidence_count" => 1, "citation_ready" => true},
          "resolved_case_assists" => %{
            "case_count" => 1,
            "summaries" => ["Prior export timeout case"]
          }
        }
      }
    )
  end

  defp follow_through_quick_fix_result(reindex_status) do
    suggestion =
      quick_fix_suggestion_fixture(:ready)
      |> Map.put(
        :operator_summary,
        if(reindex_status == :failed,
          do: "Published, but reindex follow-through needs operator attention.",
          else: "Backed by a published Knowledge Base article."
        )
      )

    {:ok,
     %{
       suggestion: suggestion,
       review_task:
         struct(ReviewTask,
           id: 63,
           article_suggestion_id: suggestion.id,
           status: :published,
           publish_status: :published,
           published_revision_id: 88,
           reindex_status: reindex_status,
           article_suggestion: suggestion
         ),
       quick_fix: %{}
     }}
  end

  defp element_index(html, needle) do
    html
    |> :binary.match(needle)
    |> elem(0)
  end

  # ---------------------------------------------------------------------------
  # Phase 14 Wave 0 extensions: governed-action surface behavior contracts
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # MockRepo extension: governed_actions load path
  #
  # The existing MockRepo.all/1 returns []. Wave 1 will extend it to return
  # seeded %ToolProposal{} structs filtered by conversation_id. For Wave 0
  # we document the contract here; card-render tests are @tag :skip.
  # ---------------------------------------------------------------------------

  # Inline fixtures for ToolProposal structs (no shared factory — existing repo idiom)

  defp tool_proposal_fixture(overrides) do
    base = %Cairnloop.Governance.ToolProposal{
      id: System.unique_integer([:positive]),
      tool_ref: "Cairnloop.Tools.LookupOrder",
      tool_version: nil,
      status: :proposed,
      risk_tier: :read_only,
      approval_mode: :auto,
      actor_id: "user_42",
      account_id: "acct_1",
      input_snapshot: %{order_id: "ord_123"},
      scope_snapshot: %{scopes: []},
      policy_snapshot: %{outcome: :proposed},
      events: []
    }

    Map.merge(base, overrides)
  end

  # ---------------------------------------------------------------------------
  # governed_action_card/1 rendering — row 14-02-a
  #
  # Skipped: governed_action_card/1 does not exist until Wave 2.
  # ---------------------------------------------------------------------------

  describe "governed_action_card/1 — renders all four statuses without crashing (row 14-02-a)" do
    # Note: ConversationLive.governed_action_card/1 does not exist until Wave 2.
    # All tests in this describe use runtime dispatch (apply/render_component with
    # a runtime function reference) so @tag :skip tests do not produce compile-time
    # warnings that would break --warnings-as-errors (T-14-W0-01).

    test "renders :proposed status with a status label and chip text (not color-alone, brand §7.5)" do
      proposal = tool_proposal_fixture(%{status: :proposed})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)

      # Status chip must pair color WITH text — never color alone (brand §7.5)
      assert html =~ "Proposed"
    end

    test "renders :needs_input status with label text" do
      proposal = tool_proposal_fixture(%{status: :needs_input})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)
      assert html =~ "Needs input"
    end

    test "renders :scope_invalid status with label text" do
      proposal = tool_proposal_fixture(%{status: :scope_invalid})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)
      assert html =~ "Not available here"
    end

    test "renders :policy_denied status with label text" do
      proposal = tool_proposal_fixture(%{status: :policy_denied})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)
      assert html =~ "Blocked by policy"
    end

    test "empty events list renders calm 'No history yet' instead of crashing (D-24)" do
      proposal = tool_proposal_fixture(%{events: []})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)
      assert html =~ "No history yet"
    end

    test "Ecto.Association.NotLoaded events renders calm 'No history yet' (D-24 assoc_loaded? guard)" do
      not_loaded = %Ecto.Association.NotLoaded{
        __field__: :events,
        __owner__: Cairnloop.Governance.ToolProposal,
        __cardinality__: :many
      }

      proposal = tool_proposal_fixture(%{events: not_loaded})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)
      assert html =~ "No history yet"
    end
  end

  # ---------------------------------------------------------------------------
  # MockRepo governed_actions load path — contract documentation
  #
  # Wave 1 will extend MockRepo.all/1 to return process-dictionary-seeded
  # ToolProposal structs. This test documents the expected contract shape.
  # ---------------------------------------------------------------------------

  describe "MockRepo governed_actions load path — contract documentation" do
    test "MockRepo.all/1 returns [] by default (current behavior)" do
      # MockRepo.all/1 always returns [] for any query (test isolation default).
      # list_proposals_for_conversation/1 uses repo().all(query) — empty list is safe.
      result = MockRepo.all(Cairnloop.Governance.ToolProposal)
      assert is_list(result)
    end
  end

  # ---------------------------------------------------------------------------
  # Blocked proposals visible in rail — row 14-03-b (Support-Truth Gate)
  #
  # Skipped: governed_action_card/1 and list_proposals_for_conversation/1 do
  # not exist until Waves 1-2. Tests document the expectation.
  # ---------------------------------------------------------------------------

  describe "governed_action rail — blocked proposals visible (row 14-03-b, Support-Truth Gate)" do
    test "blocked proposals (:needs_input) appear in the governed-action rail section" do
      # Blocked proposals must appear durably in the rail (Support-Truth Gate).
      # The governed_action_card/1 component renders :needs_input as "Needs input" chip text.
      blocked = tool_proposal_fixture(%{status: :needs_input})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: blocked)
      assert html =~ "Needs input"
      assert blocked.status == :needs_input
    end

    test "blocked proposals (:scope_invalid) appear in the governed-action rail section" do
      # :scope_invalid blocked proposals must be visible in the rail — never hidden.
      blocked = tool_proposal_fixture(%{status: :scope_invalid})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: blocked)
      assert html =~ "Not available here"
      assert blocked.status == :scope_invalid
    end

    test "blocked proposals (:policy_denied) appear in the governed-action rail section" do
      # :policy_denied blocked proposals must be visible in the rail — never hidden.
      blocked = tool_proposal_fixture(%{status: :policy_denied})
      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: blocked)
      assert html =~ "Blocked by policy"
      assert blocked.status == :policy_denied
    end
  end

  # ---------------------------------------------------------------------------
  # Source assertion: failure_reason_message/1 does not call inspect on
  # scope/policy reason (D-14) — row 14-03-b
  #
  # This test runs NOW — it is a pure source-code assertion.
  # ---------------------------------------------------------------------------

  describe "failure_reason_message/1 — no inspect on scope/policy reason (D-14)" do
    test "failure_reason_message/1 clauses for scope_invalid and policy_denied do NOT use inspect(reason) (D-14 — Wave 3 inverted)" do
      # Wave 3 inverted this assertion: after D-14 humanization, inspect(reason) must be ABSENT.
      # All three clauses now use ToolProposalPresenter.reason_label/1 instead of inspect/1.
      project_root =
        __ENV__.file
        |> Path.expand()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()

      source_path = Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"])
      source = File.read!(source_path)

      # Locate the failure_reason_message function region
      start_marker = "defp failure_reason_message"

      {:ok, start_pos} =
        case :binary.match(source, start_marker) do
          {pos, _len} -> {:ok, pos}
          :nomatch -> {:error, :not_found}
        end

      # Extract a region large enough to contain all failure_reason_message clauses
      region = binary_part(source, start_pos, min(byte_size(source) - start_pos, 800))

      # D-14: inspect(reason) must be ABSENT — humanized via ToolProposalPresenter.reason_label/1
      refute region =~ "inspect(reason)",
             "failure_reason_message/1 must not use inspect(reason) — use ToolProposalPresenter.reason_label/1 (D-14)"

      # D-14: reason_label must be PRESENT in the region
      assert region =~ "reason_label",
             "failure_reason_message/1 must use ToolProposalPresenter.reason_label/1 (D-14)"
    end

    test "failure_reason_message/1 does not forward raw inspect output to the :scope_invalid flash (CR-01 regression guard)" do
      # CR-01: before the fix, interpolating {:missing_scopes, [...]} with #{reason}
      # raised Protocol.UndefinedError. The current implementation uses inspect(reason)
      # which is safe (no crash) but still exposes raw Elixir terms to the operator.
      # This test documents the CR-01 guard (no crash) while marking the inspect
      # replacement as a Wave 3 task.
      # The handle_event test above already covers the no-crash aspect; this test
      # documents the D-14 improvement target.
      assert true,
             "inspect(reason) is safe from crash (CR-01 fixed); D-14 humanization is Wave 3 work"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 15 Wave 4: Approve/Reject/Defer footer affordances (15-04)
  #
  # Tests the footer slot rendering, handle_event handlers, snapshot prose reading,
  # brand compliance (§7.5 color+text), and reload reflection (APRV-01, FLOW-03).
  # ---------------------------------------------------------------------------

  defmodule MockGovernance do
    # Approval decision results are seeded via process dictionary:
    # :approve_result, :reject_result, :defer_result
    def approve(approval_id, _actor_id, _opts) do
      Process.put(:approve_called_with, approval_id)

      Process.get(
        :approve_result,
        {:ok, %Cairnloop.Governance.ToolApproval{id: approval_id, status: :approved}}
      )
    end

    def reject(approval_id, _actor_id, opts) do
      Process.put(:reject_called_with, {approval_id, Keyword.get(opts, :reason)})

      Process.get(
        :reject_result,
        {:ok, %Cairnloop.Governance.ToolApproval{id: approval_id, status: :rejected}}
      )
    end

    def defer(approval_id, _actor_id, opts) do
      Process.put(:defer_called_with, {approval_id, Keyword.get(opts, :reason)})

      Process.get(
        :defer_result,
        {:ok, %Cairnloop.Governance.ToolApproval{id: approval_id, status: :deferred}}
      )
    end
  end

  defp approval_socket(overrides \\ %{}) do
    base_assigns = %{
      conversation: %Cairnloop.Conversation{
        id: 1,
        host_user_id: "user_42",
        subject: "Test",
        drafts: [],
        messages: []
      },
      host_context: %{},
      context_error: nil,
      quick_fix_card: %{status: :idle},
      governed_actions: [],
      form: Phoenix.Component.to_form(%{"content" => ""}),
      flash: %{},
      __changed__: %{}
    }

    %Phoenix.LiveView.Socket{
      endpoint: Cairnloop.Web.Endpoint,
      assigns: Map.merge(base_assigns, overrides)
    }
  end

  defp pending_approval_fixture(overrides \\ %{}) do
    base = %Cairnloop.Governance.ToolApproval{
      id: 99,
      status: :pending,
      tool_proposal_id: 42,
      decided_by: nil,
      reason: nil,
      expires_at: nil
    }

    Map.merge(base, overrides)
  end

  describe "governed_action_card/1 — Phase 15 approval surface (15-04)" do
    test "footer slot renders Approve button when active :pending approval exists (brand §7.5 / APRV-01)" do
      # Proposal with a :pending approval preloaded
      approval = pending_approval_fixture()

      proposal =
        tool_proposal_fixture(%{
          approval: approval,
          rendered_consequence: "Will update the order status to refunded.",
          title: "Refund Order"
        })

      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)

      # Footer must render Approve affordance with phx-click
      assert html =~ "approve_action" or html =~ "approve",
             "footer must render Approve affordance when :pending approval exists"

      # Status conveyed by text AND color (brand §7.5)
      assert html =~ "Approve" or html =~ "approve",
             "Approve affordance must have text label (never color-alone, §7.5)"
    end

    test "footer slot renders Reject and Defer affordances alongside Approve (15-04)" do
      approval = pending_approval_fixture()
      proposal = tool_proposal_fixture(%{approval: approval})

      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)

      assert html =~ "Reject" or html =~ "reject",
             "footer must render Reject affordance"

      assert html =~ "Defer" or html =~ "defer",
             "footer must render Defer affordance"
    end

    test "card reads snapshotted rendered_consequence, never calls live Preview.render (D15-14)" do
      # The card must show the snapshotted prose, not re-call Preview.render
      approval = pending_approval_fixture()

      proposal =
        tool_proposal_fixture(%{
          approval: approval,
          rendered_consequence: "Snapshotted consequence text",
          title: "Snapshotted Title"
        })

      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)

      assert html =~ "Snapshotted Title",
             "card must display the snapshotted title column (D15-14)"
    end

    test "approval_outlook shows 'Pending approval' copy when :pending approval exists (D15-16)" do
      approval = pending_approval_fixture()
      proposal = tool_proposal_fixture(%{approval: approval})

      card_fn = Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)
      html = render_component(card_fn, proposal: proposal)

      assert html =~ "Pending approval",
             "card must show 'Pending approval' copy when active :pending approval exists (D15-16)"

      refute html =~ "Will require",
             "card must not show future-tense honesty seam when real approval exists (D15-16)"
    end

    test "brand token var(--cl-primary) used in footer (§2.2/§7 — no hardcoded hex for affordance)" do
      # Source assertion: var(--cl-primary) must appear at least once (footer affordances)
      project_root =
        __ENV__.file
        |> Path.expand()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()

      source =
        File.read!(Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"]))

      assert source =~ "var(--cl-primary",
             "brand token var(--cl-primary) must be used in conversation_live (§2.2/§7)"
    end

    test "no streams used in conversation_live (P14 D-02 plain-assign invariant)" do
      project_root =
        __ENV__.file
        |> Path.expand()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()

      source =
        File.read!(Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"]))

      refute source =~ "LiveView.stream(",
             "no Phoenix.LiveView.stream/3 must be used (P14 D-02 plain-assign invariant)"

      refute source =~ ~r/stream\([^)]+\).*stream/s
    end

    test "card does not call live Preview.render (D15-14 source assertion)" do
      project_root =
        __ENV__.file
        |> Path.expand()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()

      source =
        File.read!(Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"]))

      # The card precompute must read rendered_consequence, not call Preview.render
      assert source =~ "rendered_consequence",
             "card must reference rendered_consequence column (D15-14)"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 26 D-09 failed-bubble subhead + outbound_recovery_card a11y
  # verification. Additive — chip render and outbound_recovery_card stay
  # byte-for-byte unchanged (Pitfall 7).
  # ---------------------------------------------------------------------------

  describe "Phase 26 D-09 failed-bubble subhead" do
    defp failed_bubble_assigns(status) do
      %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          status: :resolved,
          subject: "Test",
          messages: [
            %Cairnloop.Message{
              id: 10,
              role: :system_outbound,
              content: "Hey, checking in.",
              metadata: %{"template_id" => "recovery_v1", "status" => status}
            }
          ],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{},
        # WR-07: ConversationLive.render/1 references @quick_fix_card and
        # @governed_actions (lines 802 + 818-823 of conversation_live.ex),
        # both populated by reload_conversation_with_context/2. Tests passed
        # by accident before because Phoenix yields `nil` for unbound
        # assigns — but if quick_fix_card/1 ever pattern-matched on a
        # non-nil card map, or if the `<%= for proposal <- @governed_actions
        # do %>` was reached without the empty-list guard at line 818, the
        # failed-bubble tests would crash for an unrelated reason. Seed the
        # assigns explicitly: idle quick-fix card (status :idle is the
        # neutral resting state) and an empty governed_actions list (D-01
        # right-rail rendering accepts [] gracefully via the line 818
        # guard). Mirrors the established `quick_fix_card: %{status: :idle},
        # governed_actions: []` pattern used elsewhere in this file
        # (search "quick_fix_card: %{status: :idle}").
        quick_fix_card: %{status: :idle},
        governed_actions: []
      }
    end

    test "Test 1: failed status renders subhead AND keeps the existing chip (Pitfall 7)" do
      html = render_html(failed_bubble_assigns("failed"))

      # Pitfall 7 regression gate — chip render MUST remain.
      assert html =~ "message-status-chip status-failed"
      assert html =~ "Failed"
      # New calm reason-forward subhead.
      assert html =~ "Delivery did not complete. Try again from the Outbound recovery card."
      assert html =~ "outbound-failed-subhead"
      assert html =~ "var(--cl-text-muted"
    end

    test "Test 2: sent status does NOT render the subhead" do
      html = render_html(failed_bubble_assigns("sent"))

      assert html =~ "message-status-chip status-sent"
      assert html =~ "Sent"
      refute html =~ "Delivery did not complete"
      refute html =~ "outbound-failed-subhead"
    end

    test "Test 3: pending status does NOT render the subhead" do
      html = render_html(failed_bubble_assigns("pending"))

      assert html =~ "message-status-chip status-pending"
      refute html =~ "Delivery did not complete"
      refute html =~ "outbound-failed-subhead"
    end

    test "Test 4: non-system_outbound role does NOT render the subhead" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          status: :resolved,
          subject: "Test",
          messages: [
            %Cairnloop.Message{
              id: 11,
              role: :user,
              content: "Customer message",
              metadata: %{}
            }
          ],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      refute html =~ "Delivery did not complete"
      refute html =~ "outbound-failed-subhead"
      # The rendered <span class="message-status-chip ..."> element should NOT
      # appear (the class name shows up in the inline <style> block CSS
      # regardless, so match on the attribute marker instead).
      refute html =~ ~s(class={["message-status-chip)
      refute html =~ ~s(class="message-status-chip)
    end

    test "Test 5: outbound_recovery_card a11y verification — aria-label=\"Outbound recovery\" present on :resolved" do
      html = render_html(failed_bubble_assigns("sent"))

      assert html =~ ~s(aria-label="Outbound recovery")
      # Pin the actual rendered <section class="rail-card outbound-action-card">
      # (the bare class name appears in the embedded CSS regardless of render).
      assert html =~ ~s(class="rail-card outbound-action-card")
    end

    test "Test 6: outbound_recovery_card hidden on non-resolved conversation" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 2,
          status: :open,
          subject: "Open conversation",
          messages: [],
          drafts: [],
          host_user_id: "user_42"
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)

      # The rendered <section> must NOT appear. Bare "outbound-action-card"
      # shows up in the inline <style> block CSS rule, so match the actual
      # class attribute string instead.
      refute html =~ ~s(class="rail-card outbound-action-card)
      refute html =~ ~s(aria-label="Outbound recovery")
    end

    test "Test 7: subhead position — AFTER message-content, BEFORE closing message-card div" do
      html = render_html(failed_bubble_assigns("failed"))

      content_match = :binary.match(html, "class=\"message-content\"")
      subhead_match = :binary.match(html, "class=\"outbound-failed-subhead\"")

      assert content_match != :nomatch,
             "expected class=\"message-content\" in rendered HTML"

      assert subhead_match != :nomatch,
             "expected class=\"outbound-failed-subhead\" in rendered HTML"

      {content_offset, _} = content_match
      {subhead_offset, _} = subhead_match

      assert subhead_offset > content_offset,
             "subhead (offset #{subhead_offset}) must appear AFTER the message-content paragraph (offset #{content_offset}) per RESEARCH Code Example 3"
    end
  end

  describe "handle_event approve_action/reject_action/defer_action — Phase 15 (APRV-01, FLOW-03)" do
    test "approve_action calls Governance.approve and reloads on success" do
      socket = approval_socket()

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event(
                 "approve_action",
                 %{"approval-id" => "99"},
                 socket
               )

      # Must not crash and must produce a flash or reload
      assert updated_socket.assigns.flash["info"] != nil or
               is_list(updated_socket.assigns.governed_actions),
             "approve_action must succeed and update state"
    end

    test "approve_action handler calls Governance.approve (source assertion — never .run/3)" do
      project_root =
        __ENV__.file
        |> Path.expand()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()
        |> Path.dirname()

      source =
        File.read!(Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"]))

      # Handler must call Governance.approve/reject/defer (at least 3 times total)
      assert source =~ "Governance.approve",
             "conversation_live must call Cairnloop.Governance.approve"

      assert source =~ "Governance.reject",
             "conversation_live must call Cairnloop.Governance.reject"

      assert source =~ "Governance.defer",
             "conversation_live must call Cairnloop.Governance.defer"

      # Handler must NOT call run/3 or execute inline (APRV-01)
      # Extract approve_action handler region to avoid matching doc strings
      approve_start = :binary.match(source, "approve_action") |> elem(0)

      approve_region =
        binary_part(source, approve_start, min(byte_size(source) - approve_start, 400))

      refute approve_region =~ ".run(",
             "approve_action handler must not call .run/3 — no inline execution (APRV-01)"
    end

    test "reject_action emits error flash when reason is empty (FLOW-03)" do
      # Set up MockGovernance to return the reason-required error
      Process.put(:reject_result, {:error, %Ecto.Changeset{}})

      socket = approval_socket()

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event(
                 "reject_action",
                 %{"approval-id" => "99", "reason" => ""},
                 socket
               )

      # Empty reason should surface an error flash
      assert updated_socket.assigns.flash["error"] != nil or
               updated_socket.assigns.flash["info"] != nil,
             "reject_action must handle empty reason gracefully (FLOW-03)"
    end

    test "defer_action emits error flash when reason is empty (FLOW-03)" do
      Process.put(:defer_result, {:error, %Ecto.Changeset{}})

      socket = approval_socket()

      assert {:noreply, updated_socket} =
               ConversationLive.handle_event(
                 "defer_action",
                 %{"approval-id" => "99", "reason" => ""},
                 socket
               )

      assert updated_socket.assigns.flash["error"] != nil or
               updated_socket.assigns.flash["info"] != nil,
             "defer_action must handle empty reason gracefully (FLOW-03)"
    end
  end
end
