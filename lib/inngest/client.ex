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

  @spec send(Event.t() | [Event.t()]) :: :ok | :error
  def send(payload) do
    :ok
  end
end
