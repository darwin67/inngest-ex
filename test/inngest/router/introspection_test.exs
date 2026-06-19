defmodule Inngest.Router.IntrospectionTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "introspection-test", name: "Introspection Test"}
  @trigger %Trigger{event: "test/router.introspection"}

  @impl true
  def exec(_ctx, _input), do: {:ok, %{"ok" => true}}
end

defmodule Inngest.Router.IntrospectionPlugRouter do
  @moduledoc false

  use Plug.Router
  use Inngest.Router, :plug

  plug(:match)
  plug(:dispatch)

  inngest("/api/inngest", funcs: [Inngest.Router.IntrospectionTestFn])

  match _ do
    send_resp(conn, 404, "not found")
  end
end

defmodule Inngest.Router.IntrospectionPhoenixRouter do
  @moduledoc false

  use Phoenix.Router
  use Inngest.Router, :phoenix

  inngest("/api/inngest", funcs: [Inngest.Router.IntrospectionTestFn])
end

defmodule Inngest.Router.IntrospectionTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Inngest.{Config, Headers, Signature}
  alias Inngest.Router.Introspection

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @fallback_signing_key "signkey-fallback-746573742d66616c6c6261636b2d7369676e696e672d6b657921"

  @env_vars ~w(
    INNGEST_API_BASE_URL
    INNGEST_DEV
    INNGEST_ENV
    INNGEST_EVENT_API_BASE_URL
    INNGEST_EVENT_KEY
    INNGEST_SERVE_ORIGIN
    INNGEST_SERVE_PATH
    INNGEST_SIGNING_KEY
    INNGEST_SIGNING_KEY_FALLBACK
  )

  @config_keys ~w(
    api_url
    app_name
    env
    event_key
    event_url
    inngest_env
    serve_origin
    serve_path
    signing_key
    signing_key_fallback
  )a

  setup do
    env = Map.new(@env_vars, &{&1, System.get_env(&1)})
    config = Map.new(@config_keys, &{&1, Application.fetch_env(:inngest, &1)})

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@config_keys, &Application.delete_env(:inngest, &1))

    Application.put_env(:inngest, :app_name, "IntrospectionApp")
    Application.put_env(:inngest, :serve_origin, "https://serve.example")
    Application.put_env(:inngest, :serve_path, "/api/inngest")

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

  describe "call/2" do
    test "returns unauthenticated introspection when unsigned" do
      conn =
        introspection_conn()
        |> Introspection.call(introspection_opts())

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert Map.keys(body) |> Enum.sort() == unauthenticated_keys()
      assert body["authentication_succeeded"] == nil
      assert body["function_count"] == 1
      assert body["has_event_key"] == true
      assert body["has_signing_key"] == false
      assert body["has_signing_key_fallback"] == false
      assert body["mode"] == "cloud"
      assert body["schema_version"] == "2024-05-24"
      refute Map.has_key?(body, "capabilities")
    end

    test "returns unauthenticated introspection when signature validation fails" do
      conn =
        introspection_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), "invalid")
        |> Introspection.call(introspection_opts())

      body = Jason.decode!(conn.resp_body)

      assert conn.status == 200
      assert Map.keys(body) |> Enum.sort() == unauthenticated_keys()
      assert body["authentication_succeeded"] == false
    end

    test "returns authenticated introspection when signature validation succeeds" do
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")
      System.put_env("INNGEST_EVENT_API_BASE_URL", "https://event.example")
      System.put_env("INNGEST_ENV", "prod")
      System.put_env("INNGEST_EVENT_KEY", "event-key")
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", @fallback_signing_key)

      signature =
        System.os_time(:second)
        |> Integer.to_string()
        |> Signature.sign(@signing_key, "")

      conn =
        introspection_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Introspection.call(introspection_opts())

      body = Jason.decode!(conn.resp_body)

      assert conn.status == 200
      assert Map.keys(body) |> Enum.sort() == authenticated_keys()
      assert body["api_origin"] == "https://api.example"
      assert body["app_id"] == "IntrospectionApp"
      assert body["authentication_succeeded"] == true
      assert body["env"] == "prod"
      assert body["event_api_origin"] == "https://event.example"
      assert body["event_key_hash"] == sha256("event-key")
      assert body["framework"] == "plug"
      assert body["function_count"] == 1
      assert body["has_event_key"] == true
      assert body["has_signing_key"] == true
      assert body["has_signing_key_fallback"] == true
      assert body["mode"] == "cloud"
      assert body["schema_version"] == "2024-05-24"
      assert body["sdk_language"] == "elixir"
      assert body["sdk_version"] == Config.sdk_version()
      assert body["serve_origin"] == "https://serve.example"
      assert body["serve_path"] == "/api/inngest"
      assert body["signing_key_hash"] == Signature.hashed_signing_key(@signing_key)

      assert body["signing_key_fallback_hash"] ==
               Signature.hashed_signing_key(@fallback_signing_key)

      refute Map.has_key?(body, "capabilities")
    end

    test "uses fallback signing key for authenticated introspection" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", @fallback_signing_key)

      signature =
        System.os_time(:second)
        |> Integer.to_string()
        |> Signature.sign(@fallback_signing_key, "")

      conn =
        introspection_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Introspection.call(introspection_opts())

      assert Jason.decode!(conn.resp_body)["authentication_succeeded"] == true
    end

    test "uses request path as authenticated serve path when none is configured" do
      Application.delete_env(:inngest, :serve_path)
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)

      conn =
        introspection_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), signed_empty_body(@signing_key))
        |> Introspection.call(introspection_opts())

      assert Jason.decode!(conn.resp_body)["serve_path"] == "/api/inngest"
    end

    test "requires non-empty app id for authenticated introspection" do
      Application.put_env(:inngest, :app_name, "")
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)

      signature =
        System.os_time(:second)
        |> Integer.to_string()
        |> Signature.sign(@signing_key, "")

      conn =
        introspection_conn()
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Introspection.call(introspection_opts())

      assert conn.status == 500
      assert Jason.decode!(conn.resp_body) == %{"error" => "app_id must not be empty"}
    end

    test "uses the same behavior for Phoenix framework metadata" do
      conn =
        introspection_conn()
        |> Introspection.call(%{introspection_opts() | framework: "phoenix"})

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["function_count"] == 1
    end

    test "Plug route exposes introspection on the serve endpoint" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      signature = signed_empty_body(@signing_key)

      conn =
        :get
        |> conn("/api/inngest")
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Inngest.Router.IntrospectionPlugRouter.call([])

      body = Jason.decode!(conn.resp_body)

      assert conn.status == 200
      assert body["framework"] == "plug"
      assert body["schema_version"] == "2024-05-24"
    end

    test "Phoenix route exposes introspection on the serve endpoint" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      signature = signed_empty_body(@signing_key)

      conn =
        :get
        |> conn("/api/inngest")
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Inngest.Router.IntrospectionPhoenixRouter.call([])

      body = Jason.decode!(conn.resp_body)

      assert conn.status == 200
      assert body["framework"] == "phoenix"
      assert body["schema_version"] == "2024-05-24"
    end
  end

  defp introspection_opts do
    %{framework: "plug", funcs: [Inngest.Router.IntrospectionTestFn]}
  end

  defp introspection_conn do
    :get
    |> conn("/api/inngest", "")
    |> Plug.Conn.put_private(:raw_body, [""])
  end

  defp unauthenticated_keys do
    ~w(
      authentication_succeeded
      function_count
      has_event_key
      has_signing_key
      has_signing_key_fallback
      mode
      schema_version
    )
    |> Enum.sort()
  end

  defp authenticated_keys do
    ~w(
      api_origin
      app_id
      authentication_succeeded
      env
      event_api_origin
      event_key_hash
      framework
      function_count
      has_event_key
      has_signing_key
      has_signing_key_fallback
      mode
      schema_version
      sdk_language
      sdk_version
      serve_origin
      serve_path
      signing_key_fallback_hash
      signing_key_hash
    )
    |> Enum.sort()
  end

  defp signed_empty_body(signing_key) do
    System.os_time(:second)
    |> Integer.to_string()
    |> Signature.sign(signing_key, "")
  end

  defp sha256(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end
end
