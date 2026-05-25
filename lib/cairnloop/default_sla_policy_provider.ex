defmodule Cairnloop.DefaultSLAPolicyProvider do
  @moduledoc """
  Default, static implementation of `Cairnloop.SLAPolicyProvider`.

  Provides reasonable defaults but cannot be modified. Host applications
  should configure their own provider to allow operators to change policies.
  """
  @behaviour Cairnloop.SLAPolicyProvider

  @impl true
  def get_active_policies do
    {:ok,
     [
       %{
         priority: :low,
         target_first_response_minutes: 24 * 60,
         target_resolution_minutes: 7 * 24 * 60
       },
       %{
         priority: :normal,
         target_first_response_minutes: 4 * 60,
         target_resolution_minutes: 24 * 60
       },
       %{priority: :high, target_first_response_minutes: 60, target_resolution_minutes: 4 * 60},
       %{priority: :urgent, target_first_response_minutes: 15, target_resolution_minutes: 60}
     ]}
  end

  @impl true
  def set_policy(_priority, _attrs) do
    {:error,
     "Default SLA policy provider is read-only. Configure a custom provider in your host application to modify policies."}
  end
end
