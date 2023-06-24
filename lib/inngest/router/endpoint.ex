defmodule Inngest.Router.Endpoint do
  import Plug.Conn
  alias Inngest.Function.Args

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

    case func.mod.perform(args) do
      {:ok, resp} ->
        payload =
          case Jason.encode(resp) do
            {:ok, val} -> val
            {:error, err} -> err.message |> Jason.encode!()
          end

        conn
        |> put_resp_content_type(@content_type)
        |> send_resp(200, payload)

      {:error, error} ->
        payload =
          case Jason.encode(error) do
            {:ok, val} -> val
            {:error, err} -> err.message |> Jason.encode!()
          end

        conn
        |> put_resp_content_type(@content_type)
        |> send_resp(400, payload)
    end
  end
end
