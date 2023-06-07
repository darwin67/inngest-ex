defmodule Inngest.Client do
  alias Inngest.Event

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | [Event.t()]) :: :ok | {:error, binary()}
  def send(payload) do
    event_key = event_key()
    httpclient = httpclient()

    case Tesla.post(httpclient, "/e/#{event_key}", payload) do
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

  @spec httpclient() :: Tesla.Client.t()
  defp httpclient() do
    middleware = [
      {Tesla.Middleware.BaseUrl, Application.fetch_env!(:inngest, :event_base_url)},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  @spec event_key() :: binary()
  defp event_key() do
    case Application.fetch_env(:inngest, :event_key) do
      {:ok, key} -> key
      :error -> "test"
    end
  end
end
