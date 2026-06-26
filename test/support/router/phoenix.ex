defmodule Inngest.Test.PhoenixRouter do
  @moduledoc false

  use Phoenix.Router
  use Inngest.Router, :phoenix
  require Logger

  pipeline :inngest_api do
    plug(Plug.Logger)

    plug(Plug.Parsers,
      parsers: [:urlencoded, :json],
      pass: ["text/*"],
      body_reader: {Inngest.CacheBodyReader, :read_body, [[paths: ["/api/inngest"]]]},
      json_decoder: Jason
    )
  end

  scope "/" do
    pipe_through(:inngest_api)

    inngest("/api/inngest", client: Inngest.Test.Client)
  end

  def start_link() do
    webserver =
      {Plug.Cowboy, plug: Inngest.Test.PhoenixRouter, scheme: :http, options: [port: 4000]}

    case Supervisor.start_link([webserver], strategy: :one_for_one) do
      {:ok, _pid} = result ->
        Logger.info("Phoenix server listening on 127.0.0.1:4000")
        result

      error ->
        error
    end
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end
end
