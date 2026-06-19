defmodule Inngest.Client do
  @moduledoc """
  Module representing an Inngest client (subject to change).
  """
  alias Inngest.{Config, Event, Headers, Signature}

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | list(Event.t()), Keyword.t()) :: {:ok, map()} | {:error, binary()}
  def send(payload, opts \\ []) do
    event_key = Config.event_key()
    client = httpclient(:event, opts)

    case Tesla.post(client, "/e/#{event_key}", payload) do
      {:ok, %Tesla.Env{status: 200, body: resp}} ->
        # NOTE: because resp headers currently says text/plain
        # so http client won't automatically decode it as json
        if is_binary(resp) do
          Jason.decode(resp)
        else
          {:ok, resp}
        end

      {:ok, %Tesla.Env{status: 400}} ->
        {:error, "invalid event data"}

      {:ok, %Tesla.Env{status: 401}} ->
        {:error, "unknown ingest key"}

      {:ok, %Tesla.Env{status: 403}} ->
        {:error, "this ingest key is not authorized to send this event"}

      _ ->
        {:error, "unknown error"}
    end
  end

  # Retrieves the registration information from the Dev server.
  @doc false
  def dev_info() do
    client = httpclient(:inngest)

    case Tesla.get(client, "/dev") do
      {:ok, %Tesla.Env{status: 200, body: body} = _resp} ->
        {:ok, body}

      _ ->
        {:error, "failed to retrieve dev server info"}
    end
  end

  # Returns an HTTP client for making requests against Inngest.
  @doc false
  @spec httpclient(atom(), Keyword.t()) :: Tesla.Client.t()
  def httpclient(type, opts \\ [])

  def httpclient(:event, opts), do: client(Config.event_url(), :event, opts)
  def httpclient(:register, opts), do: client(Config.register_url(), :register, opts)
  def httpclient(:api, opts), do: client(Config.api_url(), :api, opts)
  def httpclient(type, opts), do: client(Config.inngest_url(), type, opts)

  @doc false
  @spec headers(atom(), Keyword.t()) :: [{binary(), binary()}]
  def headers(type, opts \\ []) do
    type
    |> default_headers()
    |> merge_headers(Keyword.get(opts, :headers, []))
  end

  defp client(base_url, type, opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON
    ]

    middleware = middleware ++ [{Tesla.Middleware.Headers, headers(type, opts)}]

    Tesla.client(middleware)
  end

  defp default_headers(type) do
    [
      {Headers.sdk_version(), Config.sdk_version()},
      {Headers.req_version(), Config.req_version()}
    ]
    |> maybe_env_header()
    |> maybe_auth_header(type)
  end

  defp maybe_env_header(headers) do
    case Config.env() do
      nil -> headers
      env -> headers ++ [{Headers.env(), to_string(env)}]
    end
  end

  defp maybe_auth_header(headers, type) when type in [:api, :register] do
    case Signature.hashed_signing_key(Config.signing_key()) do
      nil -> headers
      key -> headers ++ [{"authorization", "Bearer " <> key}]
    end
  end

  defp maybe_auth_header(headers, _type), do: headers

  defp merge_headers(headers, overrides) do
    override_names = MapSet.new(overrides, fn {name, _value} -> normalize_header(name) end)

    headers =
      Enum.reject(headers, fn {name, _value} -> normalize_header(name) in override_names end)

    headers ++ overrides
  end

  defp normalize_header(name) when is_atom(name),
    do: name |> Atom.to_string() |> String.downcase()

  defp normalize_header(name), do: name |> to_string() |> String.downcase()
end
