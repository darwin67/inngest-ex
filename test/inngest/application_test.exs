defmodule Inngest.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    http_client = Application.fetch_env(:inngest, :http_client)
    start_finch = Application.fetch_env(:inngest, :start_finch)
    http_client_opts = Application.fetch_env(:inngest, :http_client_opts)

    Application.delete_env(:inngest, :http_client)
    Application.delete_env(:inngest, :start_finch)
    Application.delete_env(:inngest, :http_client_opts)

    on_exit(fn ->
      restore_env(:http_client, http_client)
      restore_env(:start_finch, start_finch)
      restore_env(:http_client_opts, http_client_opts)
    end)
  end

  test "starts the SDK Finch child by default" do
    assert [{Finch, opts}] = Inngest.Application.finch_children()
    assert opts[:name] == Inngest.Finch
  end

  test "skips Finch when globally configured to use Hackney" do
    Application.put_env(:inngest, :http_client, Inngest.HTTPClient.Hackney)

    assert [] = Inngest.Application.finch_children()
  end

  test "skips Finch when explicitly disabled" do
    Application.put_env(:inngest, :start_finch, false)

    assert [] = Inngest.Application.finch_children()
  end

  test "passes Finch-specific options into the child spec" do
    Application.put_env(:inngest, :http_client_opts, pools: %{default: [size: 20]})

    assert [{Finch, opts}] = Inngest.Application.finch_children()
    assert opts[:name] == Inngest.Finch
    assert opts[:pools] == %{default: [size: 20]}
  end

  defp restore_env(key, {:ok, value}), do: Application.put_env(:inngest, key, value)
  defp restore_env(key, :error), do: Application.delete_env(:inngest, key)
end
