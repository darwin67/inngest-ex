defmodule Inngest.Event do
  defstruct [
    :name,
    :data,
    id: "",
    user: %{}
  ]

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          data: any(),
          user: map()
        }
end

defimpl Jason.Encoder, for: Inngest.Event do
  def encode(value, opts) do
    Jason.Encode.map(Map.from_struct(value), opts)
  end
end
