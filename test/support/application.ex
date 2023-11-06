defmodule Inngest.Test.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      Inngest.Test.PlugRouter
    ]

    children = if Mix.env() == :test, do: children ++ [Inngest.Test.DevServer], else: children

    opts = [strategy: :one_for_one, name: Inngest.Test.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
