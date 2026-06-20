defmodule Inngest.HTTPClient do
  @moduledoc """
  Behaviour for outbound HTTP requests made by the SDK.

  Adapters are intentionally transport-only. Inngest-specific concerns such as
  signing keys, fallback retry, event payload mutation, and response semantics
  stay in `Inngest.Client` so all adapters behave consistently.
  """

  alias Inngest.HTTPClient.{Request, Response}

  @callback request(Request.t()) :: {:ok, Response.t()} | {:error, term()}

  @doc false
  @spec encode_body(term()) :: nil | binary()
  def encode_body(nil), do: nil
  def encode_body(body) when is_binary(body), do: body
  def encode_body(body), do: Jason.encode!(body)

  @doc false
  @spec decode_body(binary(), [{binary(), binary()}]) :: term()
  def decode_body(body, headers) when is_binary(body) do
    # Inngest APIs normally return JSON, but some event responses come back as
    # text/plain JSON. Keep this heuristic here so individual adapters do not
    # each need to duplicate Tesla's former JSON middleware behavior.
    if json_response?(headers) || json_body?(body) do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _error} -> body
      end
    else
      body
    end
  end

  def decode_body(body, _headers), do: body

  @doc false
  @spec ensure_json_headers([{binary(), binary()}], term()) :: [{binary(), binary()}]
  def ensure_json_headers(headers, nil), do: headers
  def ensure_json_headers(headers, body) when is_binary(body), do: headers

  def ensure_json_headers(headers, _body) do
    # The SDK owns JSON encoding, so it also owns the matching content type.
    # Caller-provided content-type headers still win for custom payloads.
    if Enum.any?(headers, fn {name, _value} ->
         String.downcase(to_string(name)) == "content-type"
       end) do
      headers
    else
      [{"content-type", "application/json"} | headers]
    end
  end

  defp json_response?(headers) do
    Enum.any?(headers, fn {name, value} ->
      String.downcase(to_string(name)) == "content-type" &&
        value |> to_string() |> String.downcase() |> String.contains?("json")
    end)
  end

  defp json_body?(body) do
    body
    |> String.trim_leading()
    |> String.starts_with?(["{", "["])
  end
end
