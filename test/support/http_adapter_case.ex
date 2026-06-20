defmodule Inngest.Test.HTTPAdapterRouter do
  @moduledoc false

  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:dispatch)

  post "/json" do
    response = %{
      body: conn.body_params,
      content_type: Plug.Conn.get_req_header(conn, "content-type"),
      header: Plug.Conn.get_req_header(conn, "x-test")
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(201, Jason.encode!(response))
  end

  get "/text" do
    Plug.Conn.send_resp(conn, 202, "plain response")
  end

  get "/echo-query" do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(conn.query_params))
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "not found")
  end
end

defmodule Inngest.Test.HTTPAdapterCase do
  @moduledoc false

  alias Inngest.HTTPClient.Request

  def server_child_spec(port) do
    ref = Module.concat(__MODULE__, :"Cowboy#{System.unique_integer([:positive])}")

    {Plug.Cowboy,
     plug: Inngest.Test.HTTPAdapterRouter, scheme: :http, options: [port: port, ref: ref]}
  end

  def base_url(port), do: "http://127.0.0.1:#{port}"

  def json_request(base_url, adapter_opts) do
    request(base_url, adapter_opts,
      method: :post,
      path: "/json",
      body: %{ok: true},
      headers: [{"x-test", "yes"}]
    )
  end

  def text_request(base_url, adapter_opts),
    do: request(base_url, adapter_opts, method: :get, path: "/text")

  def query_request(base_url, adapter_opts) do
    request(base_url, adapter_opts,
      method: :get,
      path: "/echo-query",
      query: [a: 1, b: "two"]
    )
  end

  defp request(base_url, adapter_opts, opts) do
    path = Keyword.fetch!(opts, :path)
    query = Keyword.get(opts, :query)

    %Request{
      method: Keyword.fetch!(opts, :method),
      base_url: base_url,
      path: path,
      query: query,
      url: build_url(base_url, path, query),
      headers: Keyword.get(opts, :headers, []),
      body: Keyword.get(opts, :body),
      adapter_opts: adapter_opts,
      pool_timeout: 1_000,
      receive_timeout: 1_000,
      request_timeout: 1_000
    }
  end

  defp build_url(base_url, path, nil), do: build_url(base_url, path, [])

  defp build_url(base_url, path, query) do
    url = base_url <> path

    case URI.encode_query(query) do
      "" -> url
      encoded_query -> url <> "?" <> encoded_query
    end
  end

  def unused_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
