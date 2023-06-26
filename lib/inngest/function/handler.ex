defmodule Inngest.Function.Handler do
  @moduledoc """
  A struct that keeps info about function, and
  handles the invoking of steps
  """
  alias Inngest.Function.Step

  defstruct [:name, :file, :steps]

  @type t() :: %__MODULE__{
          name: module(),
          file: binary(),
          steps: [Step.t()]
        }
end
