defmodule Inngest.Test.Client do
  @moduledoc false

  use Inngest.Client,
    id: "test",
    mode: :dev,
    http_client: Inngest.HTTPClient.Finch,
    funcs: [
      Inngest.Test.Case.BatchFn,
      Inngest.Test.Case.CancelOnFn,
      Inngest.Test.Case.ConcurrencyFn,
      Inngest.Test.Case.DebounceFn,
      Inngest.Test.Case.DebounceWithKeyFn,
      Inngest.Test.Case.IdempotentFn,
      Inngest.Test.Case.InvokeCallerFn,
      Inngest.Test.Case.InvokeTimeoutCallerFn,
      Inngest.Test.Case.InvokedFn,
      Inngest.Test.Case.InvokedLongFn,
      Inngest.Test.Case.LoopFn,
      Inngest.Test.Case.NoStepFn,
      Inngest.Test.Case.NonRetriableError,
      Inngest.Test.Case.RateLimitFn,
      Inngest.Test.Case.RetriableError,
      Inngest.Test.Case.SendFn,
      Inngest.Test.Case.SleepFn,
      Inngest.Test.Case.SleepUntilFn,
      Inngest.Test.Case.StepFn,
      Inngest.Test.Case.WaitForEventFn
    ]
end

defmodule Inngest.Test.PlugRouter do
  @moduledoc false

  use Plug.Router
  use Inngest.Router, :plug
  require Logger

  plug(Plug.Logger)

  plug(:match)
  plug(:dispatch)

  get "/" do
    data = Jason.encode!(%{hello: "world"})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(200, data)
  end

  inngest("/api/inngest", client: Inngest.Test.Client)

  match _ do
    send_resp(conn, 404, "oops\n")
  end

  def start_link() do
    webserver =
      {Plug.Cowboy, plug: Inngest.Test.PlugRouter, scheme: :http, options: [port: 4000]}

    case Supervisor.start_link([webserver], strategy: :one_for_one) do
      {:ok, _pid} = result ->
        Logger.info("Server listening on 127.0.0.1:4000")
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
