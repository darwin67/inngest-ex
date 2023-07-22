defmodule Inngest.Router.Register do
  @moduledoc """
  The plug that handles registration request from Inngest
  """
  import Plug.Conn

  @content_type "application/json"

  def init(%{funcs: _} = opts), do: opts
  def init(opts), do: opts

  def call(conn, opts), do: exec(conn, opts)

  @spec exec(Plug.Conn.t(), map()) :: Plug.Conn.t()
  defp exec(
         %{request_path: path} = conn,
         %{funcs: funcs} = _params
       ) do
    funcs =
      funcs
      |> Enum.reduce(%{}, fn func, x ->
        slug = func.slug()
        Map.put(x, slug, func.serve(path))
      end)

    {status, resp} =
      case Inngest.Client.register(path, funcs) do
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
end
