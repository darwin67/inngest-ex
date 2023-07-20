defmodule Inngest.Client do
  @moduledoc """
  Module representing an Inngest client (subject to change).
  """
  alias Inngest.{Config, Event}

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | [Event.t()], Keyword.t()) :: :ok | {:error, binary()}
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

  def register(functions) do
    payload = %{
      url: "http://127.0.0.1:4000/api/inngest",
      v: "1",
      deployType: "ping",
      sdk: Config.sdk_version(),
      framework: "plug",
      appName: "test app",
      functions: functions |> Enum.map(& &1.serve/0)
    }

    case Tesla.post(httpclient(:inngest), "/fn/register", payload) do
      {:ok, %Tesla.Env{status: 200}} ->
        :ok

      {:ok, %Tesla.Env{status: 201}} ->
        :ok

      {:ok, %Tesla.Env{status: _, body: error}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end

  def dev_info() do
    client = httpclient(:inngest)

    case Tesla.get(client, "/dev") do
      {:ok, %Tesla.Env{status: 200, body: body} = _resp} ->
        {:ok, body}

      _ ->
        {:error, "failed to retrieve dev server info"}
    end
  end

  @spec httpclient(:event | :inngest, Keyword.t()) :: Tesla.Client.t()
  defp httpclient(type, opts \\ [])

  defp httpclient(:event, opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, Config.event_url()},
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

  defp httpclient(:inngest, opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, Config.inngest_url()},
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
