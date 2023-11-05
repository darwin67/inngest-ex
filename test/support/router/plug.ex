defmodule Inngest.Test.PlugRouter do
  use Plug.Router
  use Inngest.Router, :plug

  require Logger
  Logger.configure(level: System.get_env("DEV_LOG_LEVEL", "debug"))

  plug(Plug.Logger, log: :debug)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    body_reader: {Inngest.CacheBodyReader, :read_body, []},
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    data = Jason.encode!(%{hello: "world"})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(200, data)
  end

  inngest("/api/inngest", path: "test/support/cases/*")

  match _ do
    send_resp(conn, 404, "oops\n")
  end

  def start_server() do
    Task.async(fn ->
      webserver =
        {Plug.Cowboy, plug: Inngest.Test.PlugRouter, scheme: :http, options: [port: 4000]}

      {:ok, _} = Supervisor.start_link([webserver], strategy: :one_for_one)
      Logger.info("Server listening on 127.0.0.1:4000")

      Process.sleep(:infinity)
    end)
  end
end
