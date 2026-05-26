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
  @callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) ::
              :ok | {:error, term()} | any()

  @doc """
  Called when an outbound message is triggered.
  """
  @callback on_outbound_triggered(message :: struct(), conversation :: struct()) ::
              :ok | {:error, term()} | any()
end
