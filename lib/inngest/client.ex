defmodule Inngest.Client do
  defstruct [
    :endpoint,
    ingest_key: ""
  ]

  alias Inngest.Event

  @type t() :: %__MODULE__{
          endpoint: binary(),
          ingest_key: binary()
        }

  @dev_base_url "http://127.0.0.1:8288"

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | [Event.t()]) :: :ok | {:error, binary()}
  def send(payload) do
    event_key = System.get_env("INNGEST_EVENT_KEY", "test")
    client = httpclient()

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

  defp httpclient() do
    middleware = [
      {Tesla.Middleware.BaseUrl, @dev_base_url},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end
end
