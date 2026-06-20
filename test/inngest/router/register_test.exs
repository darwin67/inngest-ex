defmodule Inngest.Router.RegisterTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "register-test", name: "Register Test"}
  @trigger %Trigger{event: "test/router.register"}

  @impl true
  def exec(_ctx, _input), do: {:ok, %{"ok" => true}}
end

defmodule Inngest.Router.RegisterClient do
  @moduledoc false

  use Inngest.Client,
    id: "register-app",
    funcs: [Inngest.Router.RegisterTestFn],
    register_url: "https://register.example",
    serve_origin: "https://serve.example",
    mode: :dev
end

defmodule Inngest.Router.RegisterTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Inngest.{Config, Headers, Signature}
  alias Inngest.Router.Register
  alias Inngest.Test.HTTPClient, as: TestHTTPClient

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"

  @env_vars ~w(
    INNGEST_DEV
    INNGEST_REGISTER_URL
    INNGEST_SERVE_ORIGIN
    INNGEST_SERVE_PATH
    INNGEST_SIGNING_KEY
  )

  @config_keys ~w(
    app_host
    env
    serve_path
    signing_key
    http_client
  )a

  setup do
    env = Map.new(@env_vars, &{&1, System.get_env(&1)})
    config = Map.new(@config_keys, &{&1, Application.fetch_env(:inngest, &1)})

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@config_keys, &Application.delete_env(:inngest, &1))

    Application.put_env(:inngest, :http_client, TestHTTPClient)
    TestHTTPClient.reset!()

    on_exit(fn ->
      TestHTTPClient.reset!()

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

  describe "call/2" do
    test "allows unsigned sync and returns the spec success shape" do
      TestHTTPClient.mock(fn %{method: :post, url: url, body: body, headers: headers} ->
        payload = json_body(body)

        assert url == "https://register.example/fn/register"
        assert payload["url"] == "https://serve.example/api/inngest"
        assert payload["appName"] == "register-app"
        assert payload["framework"] == "plug"
        sdk_header = Headers.sdk_version()
        sdk_version = Config.sdk_version()
        assert [{^sdk_header, ^sdk_version}] = header_values(headers, sdk_header)

        [function] = payload["functions"]

        assert get_in(function, ["steps", "step", "runtime", "url"]) ==
                 "https://serve.example/api/inngest?stepId=step&fnId=register-app-register-test"

        TestHTTPClient.response(200, %{})
      end)

      conn =
        ""
        |> register_conn()
        |> Register.call(register_opts())

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"message" => "registered", "modified" => true}
    end

    test "preserves an unchanged registration response" do
      TestHTTPClient.mock(fn _request -> TestHTTPClient.response(200, %{"modified" => false}) end)

      conn =
        ""
        |> register_conn()
        |> Register.call(register_opts())

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"message" => "registered", "modified" => false}
    end

    test "rejects an invalid signed sync before registration" do
      TestHTTPClient.mock(fn _request -> flunk("registration should not be called") end)

      conn =
        ""
        |> register_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), "invalid")
        |> Register.call(register_opts())

      assert conn.status == 500
      assert Jason.decode!(conn.resp_body) == %{"error" => "unable to verify signature"}
    end

    test "accepts a valid signed sync request" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)

      TestHTTPClient.mock(fn _request -> TestHTTPClient.response(200, %{}) end)

      signature =
        System.os_time(:second)
        |> Integer.to_string()
        |> Signature.sign(@signing_key, "")

      conn =
        ""
        |> register_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Register.call(register_opts())

      assert conn.status == 200
    end

    test "forwards deployId query and server kind header without adding deployId to the app URL" do
      TestHTTPClient.mock(fn %{url: url, body: body, headers: headers} ->
        payload = json_body(body)

        assert url == "https://register.example/fn/register?deployId=deploy-123"
        assert payload["url"] == "https://serve.example/api/inngest"
        assert {"x-inngest-expected-server-kind", "cloud"} in headers

        TestHTTPClient.response(202, %{})
      end)

      conn =
        ""
        |> register_conn(%{"deployId" => "deploy-123"})
        |> Plug.Conn.put_req_header(Headers.server_kind(), "cloud")
        |> Register.call(register_opts())

      assert conn.status == 200
    end

    test "keeps Phoenix framework identifier stable" do
      TestHTTPClient.mock(fn %{body: body} ->
        payload = json_body(body)

        assert payload["framework"] == "phoenix"

        TestHTTPClient.response(200, %{})
      end)

      conn =
        ""
        |> register_conn()
        |> Register.call(%{register_opts() | framework: "phoenix"})

      assert conn.status == 200
    end

    test "returns a spec error shape when registration fails" do
      TestHTTPClient.mock(fn _request -> TestHTTPClient.response(500, %{"error" => "boom"}) end)

      conn =
        ""
        |> register_conn()
        |> Register.call(register_opts())

      assert conn.status == 500
      assert Jason.decode!(conn.resp_body) == %{"error" => %{"error" => "boom"}}
    end

    test "requires a first-class client" do
      assert_raise ArgumentError, "Inngest router requires :client", fn ->
        ""
        |> register_conn()
        |> Register.call(%{framework: "plug"})
      end
    end

    test "uses configured client serve path for registered app and runtime URLs" do
      client =
        Inngest.Client.new(
          id: "register-app",
          funcs: [Inngest.Router.RegisterTestFn],
          register_url: "https://register.example",
          serve_origin: "https://serve.example",
          serve_path: "/custom/inngest",
          mode: :dev
        )

      TestHTTPClient.mock(fn %{body: body} ->
        payload = json_body(body)

        assert payload["url"] == "https://serve.example/custom/inngest"

        [function] = payload["functions"]

        assert get_in(function, ["steps", "step", "runtime", "url"]) ==
                 "https://serve.example/custom/inngest?stepId=step&fnId=register-app-register-test"

        TestHTTPClient.response(200, %{})
      end)

      conn =
        ""
        |> register_conn()
        |> Register.call(%{register_opts() | client: client})

      assert conn.status == 200
    end
  end

  defp register_opts do
    %{framework: "plug", client: Inngest.Router.RegisterClient}
  end

  defp register_conn(body, params \\ %{}) do
    :put
    |> conn("/api/inngest", body)
    |> Plug.Conn.put_private(:raw_body, [body])
    |> Map.put(:params, params)
  end

  defp header_values(headers, header) do
    Enum.filter(headers, fn {name, _value} -> name == header end)
  end

  defp json_body(body) do
    body
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
