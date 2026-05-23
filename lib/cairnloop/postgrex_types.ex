Postgrex.Types.define(
  Cairnloop.PostgrexTypes,
  Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
  []
)
