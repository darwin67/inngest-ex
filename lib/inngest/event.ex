defmodule Inngest.Event do
  @moduledoc """
  Module representing an Inngest event.

  As you might guess, `Events` are the fundamentals of an event driven system. Inngest starts and ends with events. An event is the trigger for functions to start, resume and can also hold the data for functions to operate on.

  An `Inngest.Event` looks like this:

      %{
        id: "",
        name: "event/awesome",
        data: { "hello": "world" },
        ts: 1690156151,
        v: "2023.04.14.1"
      }

  #### id - `string` optional

  The `id` field in an event payload is used for deduplication. Setting this field will make sure that only one of the events (the first one) with a similar `id` is processed.

  #### name - `string` required

  The name of the event. We recommend using lowercase dot notation for names, prepending `<prefixes>/` with a slash for organization.

  #### data - `map` required

  Any data to associate with the event. Will be serialized as JSON.

  #### ts - `integer` optional

  A timestamp integer representing the unix time (in milliseconds) at which the event occurred. Defaults to the time the Inngest receives the event if not provided.

  #### v - `string` optional

  A version identifier for a particular event payload. e.g. `2023-04-14.1`
  """

  defstruct [
    :name,
    :data,
    :ts,
    :datetime,
    :v,
    id: ""
  ]

  @type t() :: %__MODULE__{
          id: binary() | nil,
          name: binary(),
          data: map(),
          v: binary() | nil,
          ts: number() | nil,
          datetime: DateTime.t() | nil
        }

  @doc """
  Construct an Event struct from a map.
  """
  @spec from(map()) :: t()
  def from(%{} = data) do
    newmap =
      case data |> Map.get(:ts, 0) |> DateTime.from_unix(:millisecond) do
        {:ok, datetime} -> data |> Map.put(:datetime, datetime)
        _ -> data
      end

    struct(__MODULE__, newmap)
  end

  def from(_), do: %__MODULE__{}
end

defimpl Jason.Encoder, for: Inngest.Event do
  def encode(value, opts) do
    value
    |> Map.from_struct()
    |> Map.drop([:datetime])
    |> Jason.Encode.map(opts)
  end
end
