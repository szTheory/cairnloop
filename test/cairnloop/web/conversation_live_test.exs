defmodule Cairnloop.Web.ConversationLiveTest do
  use ExUnit.Case, async: false

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
            status: :pending
          }
        ]
      }
    end

    def preload(record, _), do: record
  end

  defmodule SuccessContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts), do: {:ok, %{"Plan" => "Pro"}}
  end

  defmodule NestedSuccessContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts) do
      {:ok, %{
        "identity" => %{"full_name" => "Alice", "id" => 42},
        "billing" => %{"plan" => "Pro", "tags" => ["vip", "active"]}
      }}
    end
  end

  defmodule UnsupportedContextProvider do
    @behaviour Cairnloop.ContextProvider
    def get_context("user_42", _opts) do
      {:ok, %{
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

  defmodule SimpleTool do
    use Cairnloop.Tool

    embedded_schema do
    end

    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    def can_execute?(_actor_id, _context), do: true

    def execute(_tool, _actor_id, _context) do
      {:ok, "simple action executed"}
    end
  end

  defmodule InputTool do
    use Cairnloop.Tool

    embedded_schema do
      field :reason, :string
    end

    def changeset(tool, attrs) do
      import Ecto.Changeset
      tool
      |> cast(attrs, [:reason])
      |> validate_required([:reason])
    end

    def can_execute?(_actor_id, _context), do: true

    def execute(tool, _actor_id, _context) do
      if tool.reason == "crash", do: raise "Boom"
      {:ok, "executed with #{tool.reason}"}
    end
  end

  defmodule CustomLiveView do
    use Phoenix.LiveView
    def render(assigns), do: ~H"<div>Custom</div>"
  end

  defmodule CustomUiTool do
    use Cairnloop.Tool

    embedded_schema do
    end

    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    def can_execute?(_actor_id, _context), do: true

    def execute(_tool, _actor_id, _context), do: {:ok, "custom UI"}

    def custom_ui, do: CustomLiveView
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    original_tools = Application.get_env(:cairnloop, :tools, [])
    Application.put_env(:cairnloop, :tools, [SimpleTool, InputTool])

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :context_provider)
      Application.put_env(:cairnloop, :tools, original_tools)
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
        conversation: %Cairnloop.Conversation{id: 1, subject: "Test", messages: [], drafts: []},
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)
      assert html =~ "No customer context yet"
      assert html =~ "This conversation has no host context to show. Continue with the thread, or reload after host data becomes available."
    end

    test "renders error shell with correct copy when context_error is present" do
      assigns = %{
        conversation: %Cairnloop.Conversation{id: 1, subject: "Test", messages: [], drafts: []},
        host_context: %{},
        context_error: :timeout,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)
      assert html =~ "Customer context is unavailable right now. Continue handling the conversation, then reload to try again."
      # The shell 'Customer Context' should still be visible
      assert html =~ "Customer Context"
    end

    test "renders ordered nested context sections and humanizes labels" do
      assigns = %{
        conversation: %Cairnloop.Conversation{id: 1, subject: "Test", messages: [], drafts: []},
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
        conversation: %Cairnloop.Conversation{id: 1, subject: "Test", messages: [], drafts: []},
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
    test "renders AI Draft / Audit section with draft content and inline actions" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1, subject: "Test", messages: [],
          drafts: [%Cairnloop.Automation.Draft{id: 101, content: "Hello from AI", status: :pending}]
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: nil,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)
      assert html =~ "AI Draft / Audit"
      assert html =~ "Hello from AI"
      assert html =~ "Approve & Send"
      assert html =~ "Apply to Composer" # Renamed from Edit
      assert html =~ "Discard"
    end

    test "renders inline discard confirmation when pending_discard_draft_id is set" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1, subject: "Test", messages: [],
          drafts: [%Cairnloop.Automation.Draft{id: 101, content: "Hello from AI", status: :pending}]
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""}),
        pending_discard_draft_id: 101,
        socket: %Phoenix.LiveView.Socket{}
      }

      html = render_html(assigns)
      assert html =~ "Discard draft: Remove this draft from the rail? This action is recorded and cannot be undone."
      assert html =~ "phx-click=\"confirm_discard_draft\""
      assert html =~ "phx-click=\"cancel_discard_draft\""
    end
  end

  describe "tools rendering and execution" do
    test "renders available tools in the context pane" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1, subject: "Test", messages: [],
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

    test "handle_event execute_tool executes successfully" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      assert {:noreply, socket} = ConversationLive.handle_event(
               "execute_tool",
               %{"tool" => to_string(SimpleTool), "params" => %{}},
               socket
             )
      
      assert socket.assigns.flash["info"] == "simple action executed"
    end

    test "handle_event execute_tool handles input tool successfully" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      assert {:noreply, socket} = ConversationLive.handle_event(
               "execute_tool",
               %{"tool" => to_string(InputTool), "tool_params" => %{"reason" => "refund"}},
               socket
             )
      
      assert socket.assigns.flash["info"] == "executed with refund"
    end

    test "handle_event execute_tool catches exceptions (process isolation)" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "user_42"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      assert {:noreply, socket} = ConversationLive.handle_event(
               "execute_tool",
               %{"tool" => to_string(InputTool), "tool_params" => %{"reason" => "crash"}},
               socket
             )
      
      assert socket.assigns.flash["error"] == "Tool execution failed: Boom"
    end
    
    test "handle_event execute_tool catches unauthorized access" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: Cairnloop.Web.Endpoint,
        assigns: %{
          conversation: %Cairnloop.Conversation{id: 1, host_user_id: "unauthorized"},
          host_context: %{"id" => "123"},
          flash: %{},
          __changed__: %{}
        }
      }

      defmodule DeniedTool do
        use Cairnloop.Tool
        embedded_schema do end
        def changeset(t, attrs), do: Ecto.Changeset.cast(t, attrs, [])
        def can_execute?(_actor, _context), do: false
        def execute(_t, _a, _c), do: {:ok, "done"}
      end
      
      assert {:noreply, socket} = ConversationLive.handle_event(
               "execute_tool",
               %{"tool" => to_string(DeniedTool), "params" => %{}},
               socket
             )
             
      assert socket.assigns.flash["error"] == "Not authorized to execute this tool."
    end
  end

  defp render_html(assigns) do
    assigns
    |> ConversationLive.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
