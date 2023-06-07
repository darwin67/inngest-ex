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
