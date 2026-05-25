defmodule Cairnloop.Workers.IngestScrypathTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Cairnloop.Repo

  alias Cairnloop.Workers.IngestScrypath

  describe "perform/1" do
    test "processes valid arguments and indexes to scrypath" do
      Req.Test.stub(Cairnloop.ScrypathApi, fn conn ->
        Req.Test.json(conn, %{success: true})
      end)

      # Inject the stub
      Application.put_env(:cairnloop, :scrypath_req_options,
        plug: {Req.Test, Cairnloop.ScrypathApi}
      )

      job = %Oban.Job{
        args: %{
          "conversation_id" => "conv_123",
          "text" => "User issue resolved successfully."
        }
      }

      assert :ok = IngestScrypath.perform(job)
    end
  end
end
