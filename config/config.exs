import Config

config :cairnloop, Cairnloop.Repo, types: Cairnloop.PostgrexTypes

# Phase 16: Register the example governed-write tool (ACT-01, D16-02).
# Hosts add their own tools to this list; InternalNote is the reference implementation.
# The ToolRegistry resolves modules by Atom.to_string comparison — never String.to_existing_atom.
config :cairnloop, :tools, [Cairnloop.Tools.InternalNote]

import_config "#{config_env()}.exs"
