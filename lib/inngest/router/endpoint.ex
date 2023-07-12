defmodule Inngest.Router.Endpoint do
  import Plug.Conn
  alias Inngest.Function.Handler

  @content_type "application/json"

  def register(conn, %{funcs: funcs} = _params) do
    {status, resp} =
      case Inngest.Client.register(funcs) do
        :ok ->
          {200, %{}}

        {:error, error} ->
          {400, error}
      end

    resp =
      case Jason.encode(resp) do
        {:ok, val} -> val
        {:error, error} -> error
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, resp)
  end

  # NOTES:
  # *********  RESPONSE  ***********
  # Each results has a specific meaning to it.
  # status, data
  # 206, generatorcode -> store result and continue execution
  # 200, resp -> execution completed (including steps) of function
  # 400, error -> non retriable error
  # 500, error -> retriable error
  @spec invoke(Plug.Conn.t(), map) :: Plug.Conn.t()
  def invoke(
        %{assigns: %{funcs: funcs}} = conn,
        %{"event" => event, "ctx" => ctx, "fnId" => fn_slug} = params
      ) do
    func = Map.get(funcs, fn_slug)

    args = %{
      event: Inngest.Event.from(event),
      run_id: Map.get(ctx, "run_id"),
      params: params
    }

    {status, resp} =
      func.mod.__handler__()
      |> Handler.invoke(args)

    payload =
      case Jason.encode(resp) do
        {:ok, val} -> val
        {:error, err} -> Jason.encode!(err.message)
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, payload)
  end
end
