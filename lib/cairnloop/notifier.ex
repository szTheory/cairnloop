defmodule Cairnloop.Notifier do
  @moduledoc """
  Behaviour for notifying the host application of important Cairnloop events.
  """

  @doc """
  Called when a conversation is resolved. 
  Metadata may contain :sentiment, :intent, etc.
  """
  @callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()
end
