defmodule Inngest.Function.Opts do
  @moduledoc false

  defstruct [
    :id,
    :name,
    :retries
  ]

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          retries: number()
        }
end
