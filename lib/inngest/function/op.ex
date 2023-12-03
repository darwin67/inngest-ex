defmodule Inngest.Function.UnhashedOp do
  @moduledoc false

  alias Inngest.Function.Context

  defstruct [:id, :op, pos: 0, opts: %{}]

  @type t() :: %__MODULE__{
          id: binary(),
          op: binary(),
          pos: number(),
          opts: map()
        }

  # TODO: try using ETS tables
  # probably need to be on function starts
  @spec new(Context.t(), t()) :: t()
  def new(%{steps: steps} = ctx, %{id: id, pos: pos} = op) do
    id = if pos > 0, do: "#{id}:#{pos}", else: id
    hash = :crypto.hash(:sha, id) |> Base.encode16()

    case Map.get(steps, hash) do
      nil -> op
      _ -> new(ctx, %{op | pos: pos + 1})
    end
  end

  @spec hash(t()) :: binary()
  def hash(%{id: id, pos: 0} = _op) do
    :crypto.hash(:sha, id) |> Base.encode16()
  end

  def hash(%{id: id, pos: pos} = _op) do
    :crypto.hash(:sha, "#{id}:#{pos}") |> Base.encode16()
  end
end

defmodule Inngest.Function.GeneratorOpCode do
  @moduledoc false

  defstruct [
    # op represents the type of operation invoked in the function
    :op,
    # id represents a hashed unique ID for the operation. This acts
    # as the generated step ID for the state store
    :id,
    # name represents the name of the step, or the sleep duration
    # for sleeps
    :name,
    # display_name represents the display name of the step on the UI
    :display_name,
    # opts indicate the options for the operation, e.g matching
    # expressions when setting up async event listeners via
    # `waitForEvent`, or retry policies for steps
    :opts,
    # data is the resulting data from the operation, e.g. the step
    # output
    :data
  ]

  @type t() :: %__MODULE__{
          op: binary(),
          id: binary(),
          name: binary(),
          display_name: binary(),
          opts: any(),
          data: any()
        }
end

defimpl Jason.Encoder, for: Inngest.Function.GeneratorOpCode do
  def encode(value, opts) do
    value
    |> Map.put(:displayName, Map.get(value, :display_name))
    |> Jason.Encode.map(opts)
  end
end
