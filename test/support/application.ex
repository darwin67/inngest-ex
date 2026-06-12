defmodule Inngest.Test.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      Inngest.Test.PlugRouter
    ]

    children =
      if start_dev_server?(),
        do: children ++ [Inngest.Test.DevServer],
        else: children

    opts = [strategy: :one_for_one, name: Inngest.Test.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_dev_server? do
    System.get_env("MIX_ENV") == "test" && System.get_env("UNIT") != "true"
  end
end
