defmodule Inngest.Client do
  @moduledoc """
  Module representing an Inngest client (subject to change).
  """

  alias Inngest.Event

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | [Event.t()]) :: :ok | {:error, binary()}
  def send(payload) do
    event_key = Application.get_env(:inngest, :event_key, "test")
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

  def dev_info() do
    httpclient = httpclient()

    case Tesla.get(httpclient, "/dev") do
      {:ok, %Tesla.Env{status: 200, body: body} = _resp} ->
        body

      _ ->
        {:error, "failed to retrieve dev server info"}
    end
  end

  @spec httpclient() :: Tesla.Client.t()
  defp httpclient() do
    middleware = [
      {Tesla.Middleware.BaseUrl, Application.get_env(:inngest, :event_base_url)},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end
end
