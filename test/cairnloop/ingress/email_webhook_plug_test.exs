defmodule Cairnloop.Ingress.EmailWebhookPlugTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias Cairnloop.Ingress.EmailWebhookPlug
  alias Cairnloop.Ingress.EmailWebhookVerifier
  alias Cairnloop.Workers.ProcessMessage

  defmodule ExplodingBodyAdapter do
    def read_req_body(_state, _opts), do: raise("read_body should not be reached")

    def send_resp({adapter, state}, status, headers, body) do
      {:ok, body, state} = adapter.send_resp(state, status, headers, body)
      {:ok, body, {adapter, state}}
    end
  end

  defmodule ModuleVerifier do
    def verify(conn) do
      case get_req_header(conn, "x-module-signature") do
        ["valid-module-signature"] -> {:ok, :verified}
        _ -> {:error, :unauthorized}
      end
    end
  end

  defmodule RawBodyVerifier do
    def verify(_conn, body) do
      if body =~ "Raw body verifier text" do
        {:ok, :verified}
      else
        {:error, :unauthorized}
      end
    end
  end

  setup do
    original_token = Application.get_env(:cairnloop, :email_webhook_token)
    original_verifier = Application.get_env(:cairnloop, :email_webhook_verifier)

    on_exit(fn ->
      restore_env(:email_webhook_token, original_token)
      restore_env(:email_webhook_verifier, original_verifier)
    end)

    :ok
  end

  test "verifier fails closed when neither token nor host verifier is configured" do
    Application.delete_env(:cairnloop, :email_webhook_token)
    Application.delete_env(:cairnloop, :email_webhook_verifier)

    conn =
      conn(:post, "/", "{}")
      |> put_req_header("x-webhook-token", "secret-token")

    assert {:error, :unauthorized} = EmailWebhookVerifier.verify(conn)
  end

  test "does not accept the old literal development token by default" do
    Application.delete_env(:cairnloop, :email_webhook_token)
    Application.delete_env(:cairnloop, :email_webhook_verifier)

    conn =
      unreadable_conn(:post, "/", "{}")
      |> put_req_header("x-webhook-token", "secret-token")
      |> EmailWebhookPlug.call(enqueue: &flunk_enqueue/1)

    assert conn.status == 401
    assert conn.halted
    assert Jason.decode!(conn.resp_body) == %{"error" => "Unauthorized"}
  end

  test "requires a configured token" do
    Application.put_env(:cairnloop, :email_webhook_token, "configured-token")
    Application.delete_env(:cairnloop, :email_webhook_verifier)

    conn =
      unreadable_conn(:post, "/", "{}")
      |> put_req_header("x-webhook-token", "wrong-token")
      |> EmailWebhookPlug.call(enqueue: &flunk_enqueue/1)

    assert conn.status == 401
    assert conn.halted
    assert Jason.decode!(conn.resp_body) == %{"error" => "Unauthorized"}
  end

  test "configured token allows JSON parse and ProcessMessage enqueue path" do
    Application.put_env(:cairnloop, :email_webhook_token, "configured-token")
    Application.delete_env(:cairnloop, :email_webhook_verifier)

    conn =
      conn(:post, "/", Jason.encode!(%{"TextBody" => "Reply body\n\nOn Monday wrote:"}))
      |> put_req_header("x-webhook-token", "configured-token")
      |> EmailWebhookPlug.call(enqueue: enqueue_to_parent(self()))

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}

    assert_receive {:enqueued_email,
                    %Oban.Job{
                      args: %{channel: "email", content: "Reply body"},
                      worker: worker
                    }}

    assert worker == inspect(ProcessMessage)
  end

  test "configured host verifier allows JSON parse and ProcessMessage enqueue path" do
    Application.delete_env(:cairnloop, :email_webhook_token)

    Application.put_env(:cairnloop, :email_webhook_verifier, fn conn ->
      case get_req_header(conn, "x-host-signature") do
        ["valid-signature"] -> {:ok, :verified}
        _ -> {:error, :unauthorized}
      end
    end)

    conn =
      conn(:post, "/", Jason.encode!(%{"text" => "Verifier body"}))
      |> put_req_header("x-host-signature", "valid-signature")
      |> EmailWebhookPlug.call(enqueue: enqueue_to_parent(self()))

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}

    assert_receive {:enqueued_email,
                    %Oban.Job{
                      args: %{channel: "email", content: "Verifier body"}
                    }}
  end

  test "configured module verifier is loaded before callback export check" do
    Application.delete_env(:cairnloop, :email_webhook_token)
    Application.put_env(:cairnloop, :email_webhook_verifier, ModuleVerifier)

    conn =
      conn(:post, "/", Jason.encode!(%{"text" => "Module verifier body"}))
      |> put_req_header("x-module-signature", "valid-module-signature")
      |> EmailWebhookPlug.call(enqueue: enqueue_to_parent(self()))

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}

    assert_receive {:enqueued_email,
                    %Oban.Job{
                      args: %{channel: "email", content: "Module verifier body"}
                    }}
  end

  test "configured raw-body verifier receives the body without consuming it twice" do
    Application.delete_env(:cairnloop, :email_webhook_token)
    Application.put_env(:cairnloop, :email_webhook_verifier, RawBodyVerifier)

    conn =
      conn(:post, "/", Jason.encode!(%{"text" => "Raw body verifier text"}))
      |> EmailWebhookPlug.call(enqueue: enqueue_to_parent(self()))

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}

    assert_receive {:enqueued_email,
                    %Oban.Job{
                      args: %{channel: "email", content: "Raw body verifier text"}
                    }}
  end

  test "enqueue failure returns unavailable instead of acknowledging dropped email" do
    Application.put_env(:cairnloop, :email_webhook_token, "configured-token")
    Application.delete_env(:cairnloop, :email_webhook_verifier)

    conn =
      conn(:post, "/", Jason.encode!(%{"TextBody" => "Durable queue unavailable"}))
      |> put_req_header("x-webhook-token", "configured-token")
      |> EmailWebhookPlug.call(enqueue: fn _changeset -> {:error, :queue_unavailable} end)

    assert conn.status == 503
    assert conn.halted
    assert Jason.decode!(conn.resp_body) == %{"error" => "Queue unavailable"}
  end

  defp unreadable_conn(method, path, body) do
    conn = conn(method, path, body)
    %{conn | adapter: {ExplodingBodyAdapter, conn.adapter}}
  end

  defp enqueue_to_parent(parent) do
    fn changeset ->
      job = Ecto.Changeset.apply_changes(changeset)
      send(parent, {:enqueued_email, job})
      {:ok, job}
    end
  end

  defp flunk_enqueue(_changeset), do: flunk("Oban enqueue should not be reached")

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
end
