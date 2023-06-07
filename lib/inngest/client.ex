defmodule Inngest.Client do
  defstruct [
    :endpoint,
    :ingest_key
  ]

  alias Inngest.Event

  @type t() :: %__MODULE__{
          endpoint: binary() | nil,
          ingest_key: binary()
        }

  @dev_base_url "http://127.0.0.1:8288"

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(t(), Event.t() | [Event.t()]) :: :ok | {:error, binary()}
  def send(client, payload) do
    event_key = event_key(client)
    httpclient = httpclient(client)

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

  @spec httpclient(t()) :: Tesla.Client.t()
  defp httpclient(client) do
    base_url =
      case client.endpoint do
        nil -> @dev_base_url
        url -> url
      end

    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  @spec event_key(t()) :: binary()
  defp event_key(client) do
    with nil <- System.get_env("INNGEST_EVENT_KEY"),
         nil <- client.ingest_key do
      "test"
    else
      key -> key
    end
  end
end
