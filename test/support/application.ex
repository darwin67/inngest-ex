defmodule Inngest.Test.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Load env
    Dotenv.load()

    children = [
      Inngest.Test.PlugRouter
    ]

    opts = [strategy: :one_for_one, name: Inngest.Test.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
