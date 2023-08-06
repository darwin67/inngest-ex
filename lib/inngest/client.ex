defmodule Inngest.Client do
  @moduledoc """
  Module representing an Inngest client (subject to change).
  """
  alias Inngest.{Config, Event}

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | list(Event.t()), Keyword.t()) :: :ok | {:error, binary()}
  def send(payload, opts \\ []) do
    event_key = Config.event_key()
    client = httpclient(:event, opts)

    case Tesla.post(client, "/e/#{event_key}", payload) do
      {:ok, %Tesla.Env{status: 200}} ->
        :ok

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

  @doc """
  Retrieves the registration information from the Dev server.
  """
  def dev_info() do
    client = httpclient(:inngest)

    case Tesla.get(client, "/dev") do
      {:ok, %Tesla.Env{status: 200, body: body} = _resp} ->
        {:ok, body}

      _ ->
        {:error, "failed to retrieve dev server info"}
    end
  end

  @doc """
  Returns an HTTP client for making requests against Inngest.
  """
  @spec httpclient(atom(), Keyword.t()) :: Tesla.Client.t()
  def httpclient(type, opts \\ [])

  def httpclient(:event, opts), do: client(Config.event_url(), opts)
  def httpclient(:register, opts), do: client(Config.register_url(), opts)
  def httpclient(:api, opts), do: client(Config.api_url(), opts)
  def httpclient(_, opts), do: client(Config.inngest_url(), opts)

  defp client(base_url, opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON
    ]

    middleware =
      if Keyword.get(opts, :headers) do
        headers = Keyword.get(opts, :headers, [])
        middleware ++ [{Tesla.Middleware.Headers, headers}]
      else
        middleware
      end

    Tesla.client(middleware)
  end
end
