defmodule Inngest.CacheBodyReader do
  @moduledoc """
  A custom Plug parser for caching raw request body
  """
  @spec read_body(Plug.Conn.t(), keyword()) :: {:ok, binary(), Plug.Conn.t()}
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.private[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end

  def read_cached_body(conn) do
    conn.private[:raw_body]
  end
end
