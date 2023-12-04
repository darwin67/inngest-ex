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

  @doc """
  Generate a new unhashed op to represent a step
  """
  @spec new(Context.t(), binary(), binary(), map()) :: t()
  def new(%{index: table} = _ctx, op, id, opts \\ %{}) do
    idx =
      case :ets.lookup(table, id) do
        [] ->
          :ets.insert(table, {id, 0})
          0

        [{_id, n}] ->
          n = n + 1
          :ets.insert(table, {id, n})
          n
      end

    %__MODULE__{id: id, op: op, pos: idx, opts: opts}
  end

  @spec hash(t()) :: binary()
  def hash(%{id: id, pos: pos} = _op) do
    key = if pos > 0, do: "#{id}:#{pos}", else: id
    :crypto.hash(:sha, key) |> Base.encode16()
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
