import Config

# Cairnloop is a host-owned library — the host app owns real dev configuration
# (Repo credentials, Oban, Endpoint). This stub exists only so the env-split
# `import_config "#{config_env()}.exs"` in config.exs resolves under MIX_ENV=dev.
