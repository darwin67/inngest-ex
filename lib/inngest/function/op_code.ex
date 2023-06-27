defmodule Inngest.Function.OpCode do
  defstruct [:code]

  @type code() :: binary()
  @type t() :: %__MODULE__{
          code: code()
        }

  # def enum(:step_none), do: 0
  def enum(:step_run), do: "Step"
  def enum(:step_planned), do: "StepPlanned"
  def enum(:step_sleep), do: "Sleep"
  def enum(:step_wait_for_event), do: "WaitForEvent"
  def enum(_), do: "None"
end

defmodule Inngest.Function.UnhashedOp do
  alias Inngest.Function.OpCode

  defstruct [:name, :op]

  @type t() :: %__MODULE__{
          name: binary(),
          op: OpCode.code()
          # opts: map()
        }

  @spec new(OpCode.code(), binary()) :: t()
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
          op: Inngest.Function.OpCode.code(),
          id: binary(),
          name: binary(),
          opts: any(),
          data: map()
        }
end
