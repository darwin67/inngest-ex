defmodule Inngest.ClientTest do
  use ExUnit.Case, async: false

  alias Inngest.{Client, Config, Headers, Signature}

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @fallback_signing_key "signkey-fallback-746573742d66616c6c6261636b2d7369676e696e672d6b657921"

  @env_vars ~w(INNGEST_API_BASE_URL INNGEST_DEV INNGEST_ENV INNGEST_SIGNING_KEY INNGEST_SIGNING_KEY_FALLBACK)
  @config_keys ~w(env inngest_env signing_key signing_key_fallback)a

  setup do
    env = Map.new(@env_vars, &{&1, System.get_env(&1)})
    config = Map.new(@config_keys, &{&1, Application.fetch_env(:inngest, &1)})
    tesla_adapter = Application.fetch_env(:tesla, :adapter)

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@config_keys, &Application.delete_env(:inngest, &1))
    Client.reset_signing_key_fallback!()

    on_exit(fn ->
      Client.reset_signing_key_fallback!()

      Enum.each(env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      Enum.each(config, fn
        {key, {:ok, value}} -> Application.put_env(:inngest, key, value)
        {key, :error} -> Application.delete_env(:inngest, key)
      end)

      case tesla_adapter do
        {:ok, adapter} -> Application.put_env(:tesla, :adapter, adapter)
        :error -> Application.delete_env(:tesla, :adapter)
      end
    end)
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
      Application.put_env(:tesla, :adapter, Tesla.Mock)
      System.put_env("INNGEST_DEV", "1")
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")

      Tesla.Mock.mock(fn %{headers: headers} ->
        refute List.keyfind(headers, "authorization", 0)

        %Tesla.Env{status: 200, body: %{"ok" => true}}
      end)

      assert {:ok, %Tesla.Env{status: 200}} = Client.get(:api, "/v0/runs/run/actions")
    end

    test "retries with fallback signing key and sticks after a successful fallback request" do
      Application.put_env(:tesla, :adapter, Tesla.Mock)
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", @fallback_signing_key)

      parent = self()
      primary_auth = "Bearer " <> Signature.hashed_signing_key(@signing_key)
      fallback_auth = "Bearer " <> Signature.hashed_signing_key(@fallback_signing_key)

      Tesla.Mock.mock(fn %{headers: headers} ->
        auth = List.keyfind(headers, "authorization", 0) |> elem(1)
        send(parent, {:auth, auth})

        case auth do
          ^primary_auth -> %Tesla.Env{status: 401, body: "unauthorized"}
          ^fallback_auth -> %Tesla.Env{status: 200, body: %{"ok" => true}}
        end
      end)

      assert {:ok, %Tesla.Env{status: 200}} = Client.get(:api, "/v0/runs/run/actions")

      assert_receive {:auth, ^primary_auth}
      assert_receive {:auth, ^fallback_auth}

      headers = Client.headers(:api)

      assert {"authorization", ^fallback_auth} = List.keyfind(headers, "authorization", 0)
    end
  end
end
