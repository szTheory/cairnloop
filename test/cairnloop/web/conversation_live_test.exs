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

    def all(_query), do: []

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
    Application.put_env(:cairnloop, :repo, MockRepo)
    original_tools = Application.get_env(:cairnloop, :tools, [])
    original_knowledge_automation = Application.get_env(:cairnloop, :knowledge_automation)
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
    test "renders the idle quick-fix card between context and draft audit cards" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 321,
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
      handler_end_marker = :binary.match(source, "defp reload_conversation_with_context") |> elem(0)
      handler_region = binary_part(source, handler_start, handler_end_marker - handler_start)

      refute handler_region =~ "String.to_existing_atom"
      refute handler_region =~ "can_execute?"
      refute handler_region =~ ".execute("
      refute handler_region =~ "try do"
      assert handler_region =~ "Governance.propose"
      assert handler_region =~ "failure_reason_message"
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

  defp render_html(assigns) do
    render_component(&ConversationLive.render/1, assigns)
  end

  defp quick_fix_socket(overrides \\ %{}) do
    base_assigns = %{
      conversation: %Cairnloop.Conversation{
        id: 321,
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
end
