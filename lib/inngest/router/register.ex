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
end
