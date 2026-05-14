defmodule Cairnloop.Notifier do
  @moduledoc """
  Behaviour for notifying the host application of important Cairnloop events.
  """

  @doc """
  Called when a conversation is resolved. 
  Metadata may contain :sentiment, :intent, etc.
  """
  @callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()

  @doc """
  Called when a service level agreement (SLA) is breached.
  """
  @callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) :: :ok | {:error, term()} | any()
end
