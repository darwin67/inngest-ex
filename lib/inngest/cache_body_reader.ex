defmodule Inngest.CacheBodyReader do
  @moduledoc """
  A custom Plug parser for caching raw request bodies.

  Inngest verifies inbound request signatures against the raw request body.
  `Plug.Parsers` consumes that body while parsing, so this reader stores the
  bytes in connection private data before the parser discards them.

  Use `paths:` to limit caching to the Inngest endpoint when the parser runs
  globally in a Phoenix endpoint:

      plug Plug.Parsers,
        parsers: [:urlencoded, :json],
        pass: ["*/*"],
        body_reader: {Inngest.CacheBodyReader, :read_body, [[paths: ["/api/inngest"]]]},
        json_decoder: Phoenix.json_library()

  Plug's multipart parser does not use the `:body_reader` option.
  """

  @raw_body_key :inngest_raw_body

  @type read_result ::
          {:ok, binary(), Plug.Conn.t()}
          | {:more, binary(), Plug.Conn.t()}
          | {:error, term()}

  @spec read_body(Plug.Conn.t(), keyword()) :: read_result()
  def read_body(conn, opts) do
    read_body(conn, opts, [])
  end

  @spec read_body(Plug.Conn.t(), keyword(), keyword()) :: read_result()
  def read_body(conn, opts, reader_opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, maybe_cache_body(conn, body, reader_opts)}

      {:more, body, conn} ->
        {:more, body, maybe_cache_body(conn, body, reader_opts)}

      {:error, _reason} = error ->
        error
    end
  end

  @spec read_cached_body(Plug.Conn.t()) :: binary()
  def read_cached_body(conn) do
    conn.private
    |> Map.get(@raw_body_key, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp maybe_cache_body(conn, body, opts) do
    if cache_body?(conn, opts) do
      Plug.Conn.put_private(conn, @raw_body_key, [body | Map.get(conn.private, @raw_body_key, [])])
    else
      conn
    end
  end

  defp cache_body?(conn, opts) do
    case Keyword.get(opts, :paths) do
      nil -> true
      paths -> normalize_path(conn.request_path) in Enum.map(List.wrap(paths), &normalize_path/1)
    end
  end

  defp normalize_path(path) when is_binary(path) do
    path
    |> String.trim_trailing("/")
    |> case do
      "" -> "/"
      normalized -> normalized
    end
  end
end
