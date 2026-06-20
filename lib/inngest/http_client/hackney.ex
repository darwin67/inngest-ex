defmodule Inngest.HTTPClient.Hackney do
  @moduledoc """
  Hackney-backed HTTP client adapter.
  """

  @behaviour Inngest.HTTPClient

  alias Inngest.HTTPClient
  alias Inngest.HTTPClient.{Request, Response}

  @impl true
  @spec request(Request.t()) :: {:ok, Response.t()} | {:error, term()}
  def request(%Request{} = request) do
    # Hackney is a supported non-default adapter and a practical bridge for
    # early Connect transport experiments, but request/response HTTP still goes
    # through the same SDK-owned request and response structs.
    body = HTTPClient.encode_body(request.body)
    headers = HTTPClient.ensure_json_headers(request.headers, request.body)

    request.method
    |> :hackney.request(request.url, headers, body, request_options(request))
    |> normalize_response()
  end

  defp request_options(%Request{} = request) do
    request.adapter_opts
    |> Keyword.delete(:name)
    |> Keyword.put_new(:connect_timeout, request.pool_timeout)
    |> Keyword.put_new(:recv_timeout, request.receive_timeout)
  end

  defp normalize_response({:ok, status, headers, client_ref}) do
    headers = normalize_headers(headers)

    case :hackney.body(client_ref) do
      {:ok, body} ->
        {:ok,
         %Response{status: status, headers: headers, body: HTTPClient.decode_body(body, headers)}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_response({:ok, status, headers}) do
    {:ok, %Response{status: status, headers: normalize_headers(headers)}}
  end

  defp normalize_response({:error, error}), do: {:error, error}

  defp normalize_headers(headers) do
    Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
  end
end
