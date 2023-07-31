defmodule Inngest.Event do
  @moduledoc """
  Module representing an Inngest event.
  """

  defstruct [
    :name,
    :data,
    :ts,
    :datetime,
    :v,
    id: "",
    user: %{}
  ]

  @type t() :: %__MODULE__{
          id: binary() | nil,
          name: binary(),
          data: any(),
          user: map() | nil,
          v: binary() | nil,
          ts: number() | nil,
          datetime: DateTime.t() | nil
        }

  @doc """
  Construct an Event struct from a map.
  """
  @spec from(map()) :: t()
  def from(data) do
    newmap =
      for {key, val} <- data, into: %{} do
        {String.to_existing_atom(key), val}
      end

    newmap =
      case newmap |> Map.get(:ts, 0) |> DateTime.from_unix(:millisecond) do
        {:ok, datetime} -> newmap |> Map.put(:datetime, datetime)
        _ -> newmap
      end

    struct(__MODULE__, newmap)
  end
end

defimpl Jason.Encoder, for: Inngest.Event do
  def encode(value, opts) do
    Jason.Encode.map(Map.from_struct(value), opts)
  end
end
