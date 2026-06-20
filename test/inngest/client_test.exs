defmodule Inngest.ClientTest do
  use ExUnit.Case, async: false

  alias Inngest.{Client, Config, Event, Headers, Signature}
  alias Inngest.HTTPClient.Response
  alias Inngest.Test.HTTPClient, as: TestHTTPClient

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @fallback_signing_key "signkey-fallback-746573742d66616c6c6261636b2d7369676e696e672d6b657921"

  defmodule FirstFunction do
  end

  defmodule SecondFunction do
  end

  defmodule ClientMiddleware do
    @behaviour Inngest.Middleware

    @impl true
    def transform_send_event(%{events: events} = args, opts) do
      tag = Keyword.fetch!(opts, :tag)

      events =
        Enum.map(events, fn event ->
          update_in(event.data, &Map.put(&1, :middleware, tag))
        end)

      %{args | events: events}
    end

    @impl true
    def wrap_send_event(%{next: next}, opts) do
      case next.() do
        {:ok, response} -> {:ok, Map.put(response, "middleware", Keyword.fetch!(opts, :tag))}
        result -> result
      end
    end
  end

  defmodule FirstClient do
    use Inngest.Client,
      id: "first-client",
      funcs: [FirstFunction],
      api_url: "https://client-api.example",
      event_url: "https://client-events.example",
      register_url: "https://client-register.example",
      inngest_url: "https://client-app.example",
      serve_origin: "https://client-serve.example",
      serve_path: "/client/inngest",
      event_key: "client-event-key",
      signing_key: "client-signing-key",
      signing_key_fallback: "client-fallback-key",
      env: "client-env",
      mode: :dev
  end

  defmodule SecondClient do
    use Inngest.Client,
      id: "second-client",
      funcs: [SecondFunction],
      env: "second-env"
  end

  defmodule MiddlewareClient do
    use Inngest.Client,
      id: "middleware-client",
      funcs: [],
      middleware: [{ClientMiddleware, tag: "client"}]
  end

  defmodule EnvBackedClient do
    use Inngest.Client,
      id: "env-backed-client",
      funcs: []
  end

  defmodule CustomHTTPClient do
    use Inngest.Client,
      id: "custom-http-client",
      funcs: [],
      http_client: TestHTTPClient,
      http_client_opts: [pool_size: 8],
      http_pool_timeout: 1_000,
      http_receive_timeout: 2_000,
      http_request_timeout: 3_000
  end

  @env_vars ~w(
    INNGEST_API_BASE_URL
    INNGEST_BASE_URL
    INNGEST_DEV
    INNGEST_ENV
    INNGEST_EVENT_API_BASE_URL
    INNGEST_EVENT_KEY
    INNGEST_EVENT_URL
    INNGEST_REGISTER_URL
    INNGEST_SERVE_ORIGIN
    INNGEST_SERVE_PATH
    INNGEST_SIGNING_KEY
    INNGEST_SIGNING_KEY_FALLBACK
    INNGEST_URL
  )

  @config_keys ~w(
    api_url
    env
    event_key
    event_url
    inngest_env
    register_url
    serve_origin
    serve_path
    signing_key
    signing_key_fallback
    http_client
    http_client_opts
    http_pool_timeout
    http_receive_timeout
    http_request_timeout
  )a

  setup do
    env = Map.new(@env_vars, &{&1, System.get_env(&1)})
    config = Map.new(@config_keys, &{&1, Application.fetch_env(:inngest, &1)})

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@config_keys, &Application.delete_env(:inngest, &1))
    Client.reset_signing_key_fallback!()
    TestHTTPClient.reset!()

    on_exit(fn ->
      Client.reset_signing_key_fallback!()
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

  describe "client module API" do
    test "defines a runtime client struct from a macro-backed module" do
      assert %Client{} = client = FirstClient.client()

      assert client.id == "first-client"
      assert client.funcs == [FirstFunction]
      assert client.mode == :dev
      assert client.env == "client-env"
      assert client.api_url == "https://client-api.example"
      assert client.event_url == "https://client-events.example"
      assert client.register_url == "https://client-register.example"
      assert client.inngest_url == "https://client-app.example"
      assert client.serve_origin == "https://client-serve.example"
      assert client.serve_path == "/client/inngest"
      assert client.event_key == "client-event-key"
      assert client.signing_key == "client-signing-key"
      assert client.signing_key_fallback == "client-fallback-key"
      assert client.sdk_version == Config.sdk_version()
      assert client.req_version == Config.req_version()
    end

    test "defines normalized middleware from a macro-backed module" do
      assert MiddlewareClient.client().middleware == [{ClientMiddleware, [tag: "client"]}]
    end

    test "explicit client config takes precedence over environment and application config" do
      System.put_env("INNGEST_API_BASE_URL", "https://env-api.example")
      System.put_env("INNGEST_EVENT_API_BASE_URL", "https://env-events.example")
      System.put_env("INNGEST_EVENT_KEY", "env-event-key")
      System.put_env("INNGEST_SIGNING_KEY", "env-signing-key")
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", "env-fallback-key")
      System.put_env("INNGEST_ENV", "env-name")
      System.put_env("INNGEST_DEV", "0")

      Application.put_env(:inngest, :api_url, "https://app-api.example")
      Application.put_env(:inngest, :event_key, "app-event-key")
      Application.put_env(:inngest, :signing_key, "app-signing-key")

      client = FirstClient.client()

      assert client.mode == :dev
      assert client.env == "client-env"
      assert client.api_url == "https://client-api.example"
      assert client.event_url == "https://client-events.example"
      assert client.event_key == "client-event-key"
      assert client.signing_key == "client-signing-key"
      assert client.signing_key_fallback == "client-fallback-key"
    end

    test "environment variables fill missing client config before defaults" do
      System.put_env("INNGEST_API_BASE_URL", "https://env-api.example")
      System.put_env("INNGEST_EVENT_API_BASE_URL", "https://env-events.example")
      System.put_env("INNGEST_REGISTER_URL", "https://env-register.example")
      System.put_env("INNGEST_URL", "https://env-app.example")
      System.put_env("INNGEST_SERVE_ORIGIN", "https://env-serve.example")
      System.put_env("INNGEST_SERVE_PATH", "/env/inngest")
      System.put_env("INNGEST_EVENT_KEY", "env-event-key")
      System.put_env("INNGEST_SIGNING_KEY", "env-signing-key")
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", "env-fallback-key")
      System.put_env("INNGEST_ENV", "env-name")
      System.put_env("INNGEST_DEV", "1")

      Application.put_env(:inngest, :api_url, "https://app-api.example")
      Application.put_env(:inngest, :event_key, "app-event-key")

      client = EnvBackedClient.client()

      assert client.mode == :dev
      assert client.env == "env-name"
      assert client.api_url == "https://env-api.example"
      assert client.event_url == "https://env-events.example"
      assert client.register_url == "https://env-register.example"
      assert client.inngest_url == "https://env-app.example"
      assert client.serve_origin == "https://env-serve.example"
      assert client.serve_path == "/env/inngest"
      assert client.event_key == "env-event-key"
      assert client.signing_key == "env-signing-key"
      assert client.signing_key_fallback == "env-fallback-key"
    end

    test "multiple client modules do not leak app identity or function lists" do
      first = FirstClient.client()
      second = SecondClient.client()

      assert first.id == "first-client"
      assert first.funcs == [FirstFunction]
      assert first.env == "client-env"

      assert second.id == "second-client"
      assert second.funcs == [SecondFunction]
      assert second.env == "second-env"
    end

    test "defaults to the built-in Finch HTTP adapter" do
      client = EnvBackedClient.client()

      assert client.http_client == Inngest.HTTPClient.Finch
    end

    test "supports client-owned HTTP adapter and timeout configuration" do
      client = CustomHTTPClient.client()

      assert client.http_client == TestHTTPClient
      assert client.http_client_opts == [pool_size: 8]
      assert client.http_pool_timeout == 1_000
      assert client.http_receive_timeout == 2_000
      assert client.http_request_timeout == 3_000
    end

    test "uses application HTTP adapter config as a compatibility fallback" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)
      Application.put_env(:inngest, :http_client_opts, pool_size: 4)
      Application.put_env(:inngest, :http_pool_timeout, 4_000)

      client = EnvBackedClient.client()

      assert client.http_client == TestHTTPClient
      assert client.http_client_opts == [pool_size: 4]
      assert client.http_pool_timeout == 4_000
    end
  end

  describe "client-owned event sending" do
    test "macro-backed client modules expose send/1" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)

      TestHTTPClient.mock(fn %{method: :post, url: url, body: body, headers: headers} ->
        assert url == "https://client-events.example/e/client-event-key"
        [event] = body
        assert event.name == "test/client.send"
        assert event.data == %{ok: true}
        assert {Headers.env(), "client-env"} in headers

        TestHTTPClient.response(200, %{"ids" => ["event-id"], "status" => 200})
      end)

      assert {:ok, %{"ids" => ["event-id"], "status" => 200}} =
               FirstClient.send(%Event{name: "test/client.send", data: %{ok: true}})
    end

    test "runtime client structs can send events directly" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)

      client =
        Client.new(
          id: "send-client",
          event_url: "https://events.example",
          event_key: "send-key",
          env: "send-env"
        )

      TestHTTPClient.mock(fn %{method: :post, url: url, body: body, headers: headers} ->
        assert url == "https://events.example/e/send-key"
        [event] = body
        assert event.name == "test/runtime.send"
        assert event.data == %{}
        assert {Headers.env(), "send-env"} in headers

        TestHTTPClient.response(200, ~s({"ids":["runtime-id"],"status":200}))
      end)

      assert {:ok, %{"ids" => ["runtime-id"], "status" => 200}} =
               Client.send(client, %Event{name: "test/runtime.send"})
    end

    test "client middleware mutates sent events and send results" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)

      client =
        Client.new(
          id: "middleware-client",
          event_url: "https://events.example",
          event_key: "send-key",
          middleware: [{ClientMiddleware, tag: "runtime"}]
        )

      TestHTTPClient.mock(fn %{method: :post, body: body} ->
        [event] = body
        assert event.data == %{middleware: "runtime"}

        TestHTTPClient.response(200, %{"ids" => ["runtime-id"], "status" => 200})
      end)

      assert {:ok,
              %{
                "ids" => ["runtime-id"],
                "middleware" => "runtime",
                "status" => 200
              }} = Client.send(client, %Event{name: "test/runtime.middleware"})
    end

    test "passes structured request metadata and per-call timeout overrides to adapters" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)

      TestHTTPClient.mock(fn request ->
        assert request.method == :post
        assert request.base_url == "https://events.example"
        assert request.path == "/e/send-key"
        assert request.query == nil
        assert request.url == "https://events.example/e/send-key"
        assert request.pool_timeout == 11
        assert request.receive_timeout == 22
        assert request.request_timeout == 33
        assert request.adapter_opts == [pool_size: 2]

        TestHTTPClient.response(200, %{"ids" => ["event-id"], "status" => 200})
      end)

      client =
        Client.new(
          id: "request-client",
          event_url: "https://events.example",
          event_key: "send-key",
          http_client_opts: [pool_size: 2]
        )

      assert {:ok, %{"ids" => ["event-id"], "status" => 200}} =
               Client.send(client, %Event{name: "test/request.metadata"},
                 http_pool_timeout: 11,
                 http_receive_timeout: 22,
                 http_request_timeout: 33
               )
    end
  end

  describe "headers/2" do
    test "includes SDK and request version headers" do
      headers = Client.headers(:event)

      assert {Headers.sdk_version(), Config.sdk_version()} in headers
      assert {Headers.req_version(), Config.req_version()} in headers
    end

    test "adds signing key authorization for API requests" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)

      headers = Client.headers(:api)
      hashed = Signature.hashed_signing_key(@signing_key)

      assert {"authorization", "Bearer " <> hashed} in headers
    end

    test "adds environment header when configured" do
      System.put_env("INNGEST_ENV", "production")

      headers = Client.headers(:event)

      assert {Headers.env(), "production"} in headers
    end

    test "does not add environment header when env is unset" do
      headers = Client.headers(:event)

      refute Enum.any?(headers, fn {name, _value} -> name == Headers.env() end)
    end

    test "does not treat legacy app env mode as the environment header" do
      Application.put_env(:inngest, :env, :dev)

      headers = Client.headers(:event)

      refute Enum.any?(headers, fn {name, _value} -> name == Headers.env() end)
    end

    test "adds environment header from application env header config" do
      Application.put_env(:inngest, :inngest_env, "app-env")

      headers = Client.headers(:event)

      assert {Headers.env(), "app-env"} in headers
    end

    test "caller-provided headers override default headers" do
      headers = Client.headers(:event, headers: [{Headers.req_version(), "custom"}])

      assert {Headers.req_version(), "custom"} in headers
      refute {Headers.req_version(), Config.req_version()} in headers
    end
  end

  describe "authenticated API requests" do
    test "returns an error when no usable signing key is configured" do
      assert {:error, "missing signing key"} = Client.get(:api, "/v0/runs/run/actions")
    end

    test "allows unsigned API requests in dev mode" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)
      System.put_env("INNGEST_DEV", "1")
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")

      TestHTTPClient.mock(fn %{headers: headers} ->
        refute List.keyfind(headers, "authorization", 0)

        TestHTTPClient.response(200, %{"ok" => true})
      end)

      assert {:ok, %Response{status: 200}} = Client.get(:api, "/v0/runs/run/actions")
    end

    test "retries with fallback signing key and sticks after a successful fallback request" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", @fallback_signing_key)

      parent = self()
      primary_auth = "Bearer " <> Signature.hashed_signing_key(@signing_key)
      fallback_auth = "Bearer " <> Signature.hashed_signing_key(@fallback_signing_key)

      TestHTTPClient.mock(fn %{headers: headers} ->
        auth = List.keyfind(headers, "authorization", 0) |> elem(1)
        send(parent, {:auth, auth})

        case auth do
          ^primary_auth -> TestHTTPClient.response(401, "unauthorized")
          ^fallback_auth -> TestHTTPClient.response(200, %{"ok" => true})
        end
      end)

      assert {:ok, %Response{status: 200}} = Client.get(:api, "/v0/runs/run/actions")

      assert_receive {:auth, ^primary_auth}
      assert_receive {:auth, ^fallback_auth}

      headers = Client.headers(:api)

      assert {"authorization", ^fallback_auth} = List.keyfind(headers, "authorization", 0)
    end
  end
end
