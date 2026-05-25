import Config

config :cairnloop, Cairnloop.Repo, types: Cairnloop.PostgrexTypes

import_config "#{config_env()}.exs"
