defmodule Inngest.Router.API do
  @moduledoc """
  Router for registering functions with Inngest
  """
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

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

  def invoke(%{assigns: %{funcs: funcs}} = conn, params) do
    funcs |> IO.inspect()
    params |> IO.inspect()

    conn
    |> json(%{hello: "world"})
  end
end
