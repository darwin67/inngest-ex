defmodule Inngest.ConfigTest do
  use ExUnit.Case, async: false

  alias Inngest.Config

  @env_vars ~w(
    INNGEST_API_BASE_URL
    INNGEST_BASE_URL
    INNGEST_DEV
    INNGEST_ENV
    INNGEST_EVENT_API_BASE_URL
    INNGEST_EVENT_KEY
    INNGEST_EVENT_URL
    INNGEST_APP_HOST
    INNGEST_REGISTER_URL
    INNGEST_SERVE_ORIGIN
    INNGEST_SERVE_PATH
    INNGEST_SIGNING_KEY
    INNGEST_SIGNING_KEY_FALLBACK
    INNGEST_URL
  )

  @config_keys ~w(
    api_url
    app_host
    env
    event_key
    event_url
    inngest_env
    register_url
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

  describe "mode/0" do
    test "defaults to cloud mode" do
      assert Config.mode() == :cloud
      refute Config.dev?()
    end

    test "supports existing app env dev mode" do
      Application.put_env(:inngest, :env, :dev)

      assert Config.mode() == :dev
      assert Config.dev?()
    end

    test "INNGEST_DEV enables dev mode" do
      System.put_env("INNGEST_DEV", "1")

      assert Config.mode() == :dev
      assert Config.dev?()
    end

    test "INNGEST_DEV takes precedence over application config" do
      Application.put_env(:inngest, :env, :dev)
      System.put_env("INNGEST_DEV", "0")

      assert Config.mode() == :cloud
      refute Config.dev?()
    end
  end

  describe "required environment variables" do
    test "environment variables take precedence over app config" do
      Application.put_env(:inngest, :event_key, "app-event-key")
      Application.put_env(:inngest, :signing_key, "app-signing-key")
      Application.put_env(:inngest, :signing_key_fallback, "app-fallback-key")
      Application.put_env(:inngest, :env, "app-env")

      System.put_env("INNGEST_EVENT_KEY", "env-event-key")
      System.put_env("INNGEST_SIGNING_KEY", "env-signing-key")
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", "env-fallback-key")
      System.put_env("INNGEST_ENV", "env-name")

      assert Config.event_key() == "env-event-key"
      assert Config.signing_key() == "env-signing-key"
      assert Config.signing_key_fallback() == "env-fallback-key"
      assert Config.env() == "env-name"
      assert Config.inngest_env() == "env-name"
    end

    test "Inngest env header value does not use legacy mode config" do
      Application.put_env(:inngest, :env, :dev)

      assert Config.env() == :dev
      assert Config.inngest_env() == nil

      Application.put_env(:inngest, :inngest_env, "app-env")

      assert Config.inngest_env() == "app-env"
    end
  end

  describe "URL configuration" do
    test "INNGEST_DEV origin targets the dev server URLs" do
      System.put_env("INNGEST_DEV", "http://localhost:9999")

      assert Config.api_url() == "http://localhost:9999"
      assert Config.event_url() == "http://localhost:9999"
      assert Config.register_url() == "http://localhost:9999"
    end

    test "base URL config applies to API and event URLs" do
      System.put_env("INNGEST_BASE_URL", "https://inngest.example")

      assert Config.api_url() == "https://inngest.example"
      assert Config.event_url() == "https://inngest.example"
      assert Config.register_url() == "https://inngest.example"
    end

    test "specific API and event URL env vars override base URL" do
      System.put_env("INNGEST_BASE_URL", "https://inngest.example")
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")
      System.put_env("INNGEST_EVENT_API_BASE_URL", "https://events.example")

      assert Config.api_url() == "https://api.example"
      assert Config.register_url() == "https://api.example"
      assert Config.event_url() == "https://events.example"
    end

    test "serve origin uses spec env var and does not read INNGEST_APP_HOST" do
      System.put_env("INNGEST_APP_HOST", "https://old.example")

      assert Config.app_host() == "http://127.0.0.1:4000"

      System.put_env("INNGEST_SERVE_ORIGIN", "https://serve.example")

      assert Config.app_host() == "https://serve.example"
    end

    test "preserves app config support for serve origin and path" do
      Application.put_env(:inngest, :serve_origin, "https://app.example")
      Application.put_env(:inngest, :serve_path, "/api/inngest")

      assert Config.app_host() == "https://app.example"
      assert Config.serve_path() == "/api/inngest"
    end
  end

  test "uses spec SDK and request versions" do
    assert Config.sdk_version() =~ ~r/^inngest-ex:v\d+\.\d+\.\d+/
    assert Config.req_version() == "2"
  end
end
