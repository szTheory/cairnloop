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
    @behaviour SupportOS.ContextProvider
    def get_context("user_42", _opts), do: {:ok, %{"Plan" => "Pro"}}
  end

  defmodule ErrorContextProvider do
    @behaviour SupportOS.ContextProvider
    def get_context("user_42", _opts), do: {:error, :not_found}
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :context_provider)
    end)

    :ok
  end

  describe "mount/3 context resolution" do
    test "uses DefaultContextProvider when nothing is configured" do
      # Make sure we don't have a provider configured
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

  describe "render/1" do
    test "renders context error when present" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test Subject",
          messages: [],
          drafts: []
        },
        host_context: %{},
        context_error: :database_down,
        form: Phoenix.Component.to_form(%{"content" => ""})
      }

      html =
        assigns
        |> ConversationLive.render()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ "Context Unavailable: :database_down"
      assert html =~ "host-context error"
    end

    test "renders success context when present" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test Subject",
          messages: [],
          drafts: []
        },
        host_context: %{"Plan" => "Pro"},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""})
      }

      html =
        assigns
        |> ConversationLive.render()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ "Plan"
      assert html =~ "Pro"
      refute html =~ "Context Unavailable"
    end

    test "renders drafts with approve, edit, discard buttons when draft is pending" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test Subject",
          messages: [],
          drafts: [
            %Cairnloop.Automation.Draft{
              id: 101,
              content: "Hello from AI",
              status: :pending
            }
          ]
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""})
      }

      html =
        assigns
        |> ConversationLive.render()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ "Drafts"
      assert html =~ "Hello from AI"
      assert html =~ "Status: pending"
      assert html =~ "Approve & Send"
      assert html =~ "Edit"
      assert html =~ "Discard"
      assert html =~ "phx-click=\"approve_draft\""
      assert html =~ "phx-value-draft-id=\"101\""
    end

    test "renders drafts without buttons when draft is approved" do
      assigns = %{
        conversation: %Cairnloop.Conversation{
          id: 1,
          subject: "Test Subject",
          messages: [],
          drafts: [
            %Cairnloop.Automation.Draft{
              id: 102,
              content: "Approved AI draft",
              status: :approved
            }
          ]
        },
        host_context: %{},
        context_error: nil,
        form: Phoenix.Component.to_form(%{"content" => ""})
      }

      html =
        assigns
        |> ConversationLive.render()
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ "Approved AI draft"
      assert html =~ "Status: approved"
      refute html =~ "Approve & Send"
    end
  end
end
