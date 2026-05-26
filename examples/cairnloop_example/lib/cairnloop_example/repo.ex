defmodule CairnloopExample.Repo do
  use Ecto.Repo,
    otp_app: :cairnloop_example,
    adapter: Ecto.Adapters.Postgres
end
