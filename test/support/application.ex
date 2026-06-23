defmodule Inngest.Test.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Inngest.Finch},
      router()
    ]

    children =
      if start_dev_server?(),
        do: children ++ [Inngest.Test.DevServer],
        else: children

    opts = [strategy: :one_for_one, name: Inngest.Test.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp router do
    case System.get_env("INNGEST_TEST_ROUTER", "plug") do
      "plug" -> Inngest.Test.PlugRouter
      "phoenix" -> Inngest.Test.PhoenixRouter
      other -> raise "unsupported INNGEST_TEST_ROUTER=#{inspect(other)}"
    end
  end

  defp start_dev_server? do
    System.get_env("MIX_ENV") == "test" && System.get_env("UNIT") != "true"
  end
end
