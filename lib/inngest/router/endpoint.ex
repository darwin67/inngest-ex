defmodule Inngest.Router.Endpoint do
  @moduledoc """
  Router for registering functions with Inngest
  """
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias Inngest.Function.Args

  def register(%{assigns: %{funcs: funcs}} = conn, _params) do
    case Inngest.Client.register(funcs) do
      :ok ->
        conn |> json(%{})

      {:error, error} ->
        conn
        |> put_status(400)
        |> json(%{error: error})
    end
  end

  def invoke(%{assigns: %{funcs: funcs}} = conn, %{"event" => event, "ctx" => ctx} = params) do
    funcs |> IO.inspect()
    params |> IO.inspect()

    args = %Args{
      event: Inngest.Event.from(event),
      run_id: Map.get(ctx, "run_id")
    }

    func = Map.get(funcs, Map.get(ctx, "fn_id"))

    case func.mod.perform(args) do
      {:ok, resp} ->
        conn
        |> json(resp)

      {:error, error} ->
        conn
        |> put_status(400)
        |> json(error)
    end
  end
end
