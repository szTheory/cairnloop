defmodule Cairnloop.ScrypathConfig do
  @moduledoc """
  Normalizes optional Scrypath side-effect configuration.

  Scrypath automation is inert by default. Enabling it requires a real API URL
  and key so unsafe placeholder values never reach enqueue or HTTP boundaries.
  """

  @default_api_url "https://api.scrypath.local/v1/index"
  @default_api_key "dummy"

  @type ready_config :: %{
          api_url: String.t(),
          api_key: String.t(),
          req_options: keyword()
        }

  @type reason :: :missing_api_url | :missing_api_key | :unsafe_api_url | :unsafe_api_key
  @type status :: :disabled | {:ready, ready_config()} | {:misconfigured, [reason()]}

  @spec status(keyword()) :: status()
  def status(opts \\ []) when is_list(opts) do
    if config_value(opts, :scrypath_automation_enabled, false) == true do
      api_url = config_value(opts, :scrypath_api_url, nil)
      api_key = config_value(opts, :scrypath_api_key, nil)
      req_options = config_value(opts, :scrypath_req_options, [])

      case config_reasons(api_url, api_key) do
        [] ->
          {:ready, %{api_url: api_url, api_key: api_key, req_options: req_options || []}}

        reasons ->
          {:misconfigured, reasons}
      end
    else
      :disabled
    end
  end

  @spec ready?(keyword()) :: boolean()
  def ready?(opts \\ []) when is_list(opts) do
    match?({:ready, _config}, status(opts))
  end

  defp config_value(opts, key, default) do
    if Keyword.has_key?(opts, key) do
      Keyword.fetch!(opts, key)
    else
      Application.get_env(:cairnloop, key, default)
    end
  end

  defp config_reasons(api_url, api_key) do
    []
    |> maybe_add(missing?(api_url), :missing_api_url)
    |> maybe_add(missing?(api_key), :missing_api_key)
    |> maybe_add(not missing?(api_url) and api_url == @default_api_url, :unsafe_api_url)
    |> maybe_add(not missing?(api_key) and api_key == @default_api_key, :unsafe_api_key)
    |> Enum.reverse()
  end

  defp missing?(value), do: value in [nil, ""]
  defp maybe_add(reasons, true, reason), do: [reason | reasons]
  defp maybe_add(reasons, false, _reason), do: reasons
end
