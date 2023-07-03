defmodule Inngest.Function.UnhashedOp do
  @moduledoc """
  A struct representing an unhashed op
  """

  alias Inngest.Enums

  defstruct [:name, :op]

  @type t() :: %__MODULE__{
          name: binary(),
          op: Enums.opcode()
          # opts: map()
        }

  @spec new(Enums.opcode(), binary()) :: t()
  def new(code, name) do
    %__MODULE__{
      name: name,
      op: code
    }
  end

  def hash(unhashedop) do
    data = Map.from_struct(unhashedop) |> Jason.encode!()
    :crypto.hash(:sha, data) |> Base.encode16()
  end
end

defmodule Inngest.Function.GeneratorOpCode do
  @moduledoc """
  Generator response for incoming executor request
  """
  alias Inngest.Enums

  @derive Jason.Encoder
  defstruct [
    # op represents the type of operation invoked in the function
    :op,
    # id represents a hashed unique ID for the operation. This acts
    # as the generated step ID for the state store
    :id,
    # name represents the name of the step, or the sleep duration
    # for sleeps
    :name,
    # opts indicate the options for the operation, e.g matching
    # expressions when setting up async event listeners via
    # `waitForEvent`, or retry policies for steps
    :opts,
    # data is the resulting data from the operation, e.g. the step
    # output
    :data
  ]

  @type t() :: %__MODULE__{
          op: Enums.opcode(),
          id: binary(),
          name: binary(),
          opts: any(),
          data: map()
        }
end
