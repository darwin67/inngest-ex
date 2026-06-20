defmodule Inngest.HTTPClient.Finch do
  @moduledoc """
  Finch-backed HTTP client adapter.
  """

  @behaviour Inngest.HTTPClient

  alias Inngest.HTTPClient
  alias Inngest.HTTPClient.{Request, Response}

  @impl true
  @spec request(Request.t()) :: {:ok, Response.t()} | {:error, term()}
  def request(%Request{} = request) do
    ensure_finch!()

    # This adapter deliberately performs one request and returns the transport
    # result. Retry/auth policy belongs to Inngest.Client, not the transport.
    body = HTTPClient.encode_body(request.body)
    headers = HTTPClient.ensure_json_headers(request.headers, request.body)

    request.method
    |> Finch.build(request.url, headers, body)
    |> Finch.request(finch_name(request), request_options(request))
    |> normalize_response()
  end

  defp finch_name(%Request{adapter_opts: opts}) do
    Keyword.get(opts, :name, Inngest.Finch)
  end

  defp request_options(%Request{} = request) do
    [
      pool_timeout: request.pool_timeout,
      receive_timeout: request.receive_timeout,
      request_timeout: request.request_timeout
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp normalize_response({:ok, %{__struct__: Finch.Response} = response}) do
    headers = normalize_headers(response.headers)

    {:ok,
     %Response{
       status: response.status,
       headers: headers,
       body: HTTPClient.decode_body(response.body, headers)
     }}
  end

  defp normalize_response({:error, %{__exception__: true} = error}) do
    {:error, Exception.message(error)}
  end

  defp normalize_response({:error, error}), do: {:error, error}

  defp ensure_finch! do
    unless Code.ensure_loaded?(Finch) do
      raise """
      Inngest.HTTPClient.Finch requires the optional :finch dependency.

      Add {:finch, "~> 0.19"} to your dependencies or configure another
      Inngest.HTTPClient adapter.
      """
    end
  end

  defp normalize_headers(headers) do
    Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
  end
end
