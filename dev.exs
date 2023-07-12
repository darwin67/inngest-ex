require Logger
Logger.configure(level: :debug)

defmodule Inngest.Dev.Router do
  use Inngest.Router, :plug
  alias Inngest.Dev.{EventFn, CronFn}

  inngest("/api/inngest", funcs: [EventFn, CronFn])

  get "/" do
    data = Jason.encode!(%{hello: "world"})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(200, data)
  end

  match _ do
    send_resp(conn, 404, "oops\n")
  end
end

Task.async(fn ->
  webserver = {Plug.Cowboy, plug: Inngest.Dev.Router, scheme: :http, options: [port: 4000]}
  {:ok, _} = Supervisor.start_link([webserver], strategy: :one_for_one)
  Logger.info("Server listening on 127.0.0.1:4000")

  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
