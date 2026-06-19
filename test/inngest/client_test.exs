defmodule Inngest.ClientTest do
  use ExUnit.Case, async: false

  alias Inngest.{Client, Config, Headers, Signature}

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"

  @env_vars ~w(INNGEST_ENV INNGEST_SIGNING_KEY)
  @config_keys ~w(env signing_key)a

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

    test "caller-provided headers override default headers" do
      headers = Client.headers(:event, headers: [{Headers.req_version(), "custom"}])

      assert {Headers.req_version(), "custom"} in headers
      refute {Headers.req_version(), Config.req_version()} in headers
    end
  end
end
