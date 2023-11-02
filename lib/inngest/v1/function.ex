defmodule Inngest.V1.Function do
  alias Inngest.Config

  defmacro __using__(_opts) do
  end
end

defmodule Inngest.Function.Opts do
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
