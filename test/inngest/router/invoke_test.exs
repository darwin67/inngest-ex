defmodule Inngest.Router.InvokeTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-auth-test", name: "Invoke Auth Test"}
  @trigger %Trigger{event: "test/router.invoke"}

  @impl true
  def exec(_ctx, _input), do: {:ok, %{"ok" => true}}
end

defmodule Inngest.Router.InvokeTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Inngest.{Config, Headers, Signature}
  alias Inngest.Router.Invoke

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @fallback_signing_key "signkey-fallback-746573742d66616c6c6261636b2d7369676e696e672d6b657921"

  @env_vars ~w(INNGEST_DEV INNGEST_SIGNING_KEY INNGEST_SIGNING_KEY_FALLBACK)
  @config_keys ~w(app_name env signing_key signing_key_fallback)a

  setup do
    env = Map.new(@env_vars, &{&1, System.get_env(&1)})
    config = Map.new(@config_keys, &{&1, Application.fetch_env(:inngest, &1)})

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@config_keys, &Application.delete_env(:inngest, &1))

    on_exit(fn ->
      Enum.each(env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      Enum.each(config, fn
        {key, {:ok, value}} -> Application.put_env(:inngest, key, value)
        {key, :error} -> Application.delete_env(:inngest, key)
      end)
    end)
  end

  describe "call/2 signature verification" do
    test "accepts a cloud mode request signed with the fallback key" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", @fallback_signing_key)

      {body, params} = invoke_body()

      signature =
        System.os_time(:second)
        |> Integer.to_string()
        |> Signature.sign(@fallback_signing_key, body)

      conn =
        body
        |> invoke_conn(params)
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"ok" => true}
      assert Plug.Conn.get_resp_header(conn, Headers.sdk_version()) == [Config.sdk_version()]
      assert Plug.Conn.get_resp_header(conn, Headers.req_version()) == [Config.req_version()]
    end

    test "rejects an unsigned cloud mode request" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)

      {body, params} = invoke_body()

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 400
      assert Plug.Conn.get_resp_header(conn, Headers.no_retry()) == ["true"]
    end

    test "accepts an unsigned dev mode request" do
      System.put_env("INNGEST_DEV", "1")

      {body, params} = invoke_body()

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"ok" => true}
    end
  end

  defp invoke_body() do
    event = %{"name" => "test/router.invoke", "data" => %{}}

    params = %{
      "event" => event,
      "events" => [event],
      "ctx" => %{"run_id" => "run-1", "attempt" => 0},
      "fnId" => Inngest.Router.InvokeTestFn.slug(),
      "steps" => %{},
      "use_api" => false
    }

    {Jason.encode!(params), params}
  end

  defp invoke_conn(body, params) do
    :post
    |> conn("/api/inngest", body)
    |> Plug.Conn.put_private(:raw_body, [body])
    |> Map.put(:params, params)
  end
end
