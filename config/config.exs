import Config

config :cairnloop, Cairnloop.Repo, types: Cairnloop.PostgrexTypes

# Phase 16: Register the example governed-write tool (ACT-01, D16-02).
# Hosts add their own tools to this list; InternalNote is the reference implementation.
# The ToolRegistry resolves modules by Atom.to_string comparison — never String.to_existing_atom.
config :cairnloop, :tools, [Cairnloop.Tools.InternalNote]

# Host-swappable reply-draft engine. The default is the deterministic, zero-dependency
# ScoriaEngine (no API key required). Hosts that want model-composed replies set this to
# Cairnloop.Automation.DraftGenerator.Anthropic and provide ANTHROPIC_API_KEY at runtime.
config :cairnloop, :draft_generator, Cairnloop.Automation.ScoriaEngine

import_config "#{config_env()}.exs"
