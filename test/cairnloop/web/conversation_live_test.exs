defmodule Cairnloop.Web.ConversationLiveTest do
  use ExUnit.Case, async: true
  
  alias Cairnloop.Web.ConversationLive
  
  describe "render/1" do
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
