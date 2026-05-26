defmodule Cairnloop.Outbound do
  @moduledoc """
  Facade for programmatically triggering support lifecycle events (outbound messages).
  """
  alias Cairnloop.Message

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  @doc """
  Triggers an outbound message for a given conversation.

  ## Options
    * `:template_id` (required) - The identifier for the template to use.
    * `:content` (optional) - The content of the message. Defaults to a template reference.
    * `:schedule_in` (optional) - Delay in seconds before sending the message.
    * `:actor` (optional) - The entity triggering the outbound action for auditing.
    * `:auditor` (optional) - Custom auditor implementation.
  """
  def trigger(conversation_id, opts) do
    template_id = Keyword.fetch!(opts, :template_id)
    content = Keyword.get(opts, :content, "Outbound message using template: #{template_id}")
    schedule_in = Keyword.get(opts, :schedule_in)
    actor = Keyword.get(opts, :actor)
    auditor = Keyword.get(opts, :auditor, Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp))

    meta = %{
      conversation_id: conversation_id,
      template_id: template_id,
      schedule_in: schedule_in,
      actor: actor
    }

    Cairnloop.Telemetry.span([:outbound, :triggered], meta, fn ->
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(
          :message,
          Message.changeset(%Message{}, %{
            conversation_id: conversation_id,
            content: content,
            role: :system_outbound,
            metadata: %{
              "template_id" => template_id,
              "status" => "pending"
            }
          })
        )
        |> Ecto.Multi.merge(fn %{message: message} ->
          job_opts = if schedule_in, do: [schedule_in: schedule_in], else: []
          
          Ecto.Multi.insert(
            Ecto.Multi.new(),
            :delivery_job,
            Cairnloop.Workers.OutboundWorker.new(%{"message_id" => message.id}, job_opts)
          )
        end)
        |> auditor.audit(:outbound_trigger, actor, %{conversation_id: conversation_id, template_id: template_id})

      result = repo().transaction(multi)
      {result, meta}
    end)
  end
end
