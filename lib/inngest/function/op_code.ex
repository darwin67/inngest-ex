defmodule Inngest.Function.OpCode do
  defstruct [:code]

  @type code() :: :step_run | :step_sleep
  @type t() :: %__MODULE__{
          code: code()
        }
end

defmodule Inngest.Function.UnhashedOp do
  alias Inngest.Function.OpCode

  defstruct [:name, :opt, :opts, :pos, :parent]

  @type t() :: %__MODULE__{
          name: binary(),
          opt: OpCode.code(),
          opts: map(),
          pos: number(),
          parent: binary()
        }

  @spec new(OpCode.code(), binary()) :: t()
  def new(code, name) do
    %__MODULE__{
      name: name,
      opt: code
    }
  end
end

defmodule Inngest.Function.GeneratorOpCode do
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
