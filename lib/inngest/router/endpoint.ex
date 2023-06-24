defmodule Inngest.Router.Endpoint do
  import Plug.Conn
  alias Inngest.Function.Args
  alias Inngest.Handler

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

  def invoke(
        %{assigns: %{funcs: funcs}} = conn,
        %{"event" => event, "ctx" => ctx, "fnId" => slug} = _params
      ) do
    args = %Args{
      event: Inngest.Event.from(event),
      run_id: Map.get(ctx, "run_id")
    }

    func = Map.get(funcs, slug)
    {status, resp} = Handler.invoke(conn, func, args)

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, resp)
  end
end
