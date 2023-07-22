defmodule Inngest.CacheBodyReader do
  @moduledoc """
  Plug for caching request body
  """
  @spec read_body(Plug.Conn.t(), keyword()) :: {:ok, binary(), map()}
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    body = [body | conn.private[:raw_body] || []]
    conn = Plug.Conn.put_private(conn, :raw_body, body)
    {:ok, body, conn}
  end

  def read_cached_body(conn) do
    conn.private[:raw_body]
  end
end
