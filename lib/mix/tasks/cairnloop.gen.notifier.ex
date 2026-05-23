defmodule Mix.Tasks.Cairnloop.Gen.Notifier do
  @shortdoc "Scaffolds a Cairnloop.Notifier implementation"

  @moduledoc """
  Scaffolds a Cairnloop.Notifier implementation in your host application
  and injects the configuration into `config/config.exs`.

  ## Examples

      mix cairnloop.gen.notifier

  """
  use Mix.Task
  import Mix.Generator

  @doc false
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix cairnloop.gen.notifier is not supported inside umbrella projects")
    end

    app = Mix.Project.config()[:app] || :my_app
    app_module = Macro.camelize(to_string(app))

    assigns = [
      app_module: app_module
    ]

    target_file = "lib/#{app}/cairnloop_notifier.ex"
    create_file(target_file, notifier_template(assigns))

    inject_config(app_module)
    
    Mix.shell().info("""

    Done! A new Notifier has been generated at #{target_file}.

    Please verify your config/config.exs contains the correct configuration:
    
        config :cairnloop, :notifier, #{app_module}.CairnloopNotifier
    """)
  end

  defp inject_config(app_module) do
    config_file = "config/config.exs"
    
    config_snippet = """

    # Configure Cairnloop Notifier
    config :cairnloop, :notifier, #{app_module}.CairnloopNotifier
    """

    if File.exists?(config_file) do
      content = File.read!(config_file)
      
      unless String.contains?(content, "#{app_module}.CairnloopNotifier") do
        File.write!(config_file, content <> config_snippet)
        Mix.shell().info([:green, "* injecting ", :reset, "config/config.exs"])
      else
        Mix.shell().info([:yellow, "* skipped ", :reset, "config/config.exs (already configured)"])
      end
    else
      Mix.shell().info([:yellow, "* warning ", :reset, "could not find config/config.exs to inject configuration. Please add manually:\n#{config_snippet}"])
    end
  end

  embed_template(:notifier, """
  defmodule <%= @app_module %>.CairnloopNotifier do
    @moduledoc \"\"\"
    A callback handler for Cairnloop events.
    \"\"\"
    @behaviour Cairnloop.Notifier

    require Logger

    @impl true
    def on_conversation_resolved(conversation, metadata) do
      Logger.info("Conversation \#{conversation.id} was resolved. Metadata: \#{inspect(metadata)}")
      
      # Perform durable side-effects here (e.g., sync to CRM, send an email, update host user)
      # This runs asynchronously within a transactional Oban worker, retries are handled for you.
      
      :ok
    end
    
    @impl true
    def on_sla_breach(conversation, sla, _metadata) do
      Logger.info("SLA breach for conversation \#{conversation.id}. SLA: \#{inspect(sla)}")
      :ok
    end
  end
  """)
end
