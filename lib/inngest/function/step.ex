defmodule Inngest.Function.Step do
  @moduledoc """
    A struct representing a function step
  """

  @derive Jason.Encoder
  defstruct [
    :id,
    :name,
    :mod,
    :runtime,
    :retries,
    opts: %{}
  ]

  @type t() :: %__MODULE__{
          id: atom(),
          name: binary(),
          opts: map(),
          mod: module(),
          runtime: runtime(),
          retries: retry()
        }

  @type runtime() :: %{
          url: binary(),
          type: binary()
        }

  @type retry() :: %{
          attempts: number()
        }
end
