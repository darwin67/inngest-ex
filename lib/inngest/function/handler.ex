defmodule Inngest.Function.Handler do
  @moduledoc """
  A struct that keeps info about function, and
  handles the invoking of steps
  """
  alias Inngest.Function.{Step, UnhashedOp, GeneratorOpCode, Handler}

  defstruct [:name, :file, :steps]

  @type t() :: %__MODULE__{
          name: module(),
          file: binary(),
          steps: [Step.t()]
        }

  @doc """
  Handles the invoking of steps and runs from the executor
  """
  @spec invoke(Handler.t(), map()) :: {200 | 206 | 400 | 500, map()}
  # No steps detected
  def invoke(%{steps: []} = _handler, _params) do
    {200, %{message: "no steps detected"}}
  end

  # TODO: remove the linter ignore
  # credo:disable-for-next-line
  def invoke(
        %{steps: steps} = _handler,
        %{
          event: event,
          params: %{"steps" => data}
        } = _args
      ) do
    %{state_data: state_data, next: next} =
      steps
      |> Enum.reduce(%{state_data: %{}, next: nil}, fn step, acc ->
        %{state_data: state_data, next: next} = acc

        case next do
          nil ->
            case step.step_type do
              :exec_run ->
                case exec(step, %{event: event, data: state_data}) do
                  {:ok, result} ->
                    acc
                    |> Map.put(:state_data, Map.merge(state_data, result))

                  {:error, _error} ->
                    acc
                end

              _ ->
                hash =
                  UnhashedOp.from_step(step)
                  |> UnhashedOp.hash()

                state = Map.get(data, hash)

                state =
                  if Map.has_key?(data, hash) do
                    # credo:disable-for-next-line
                    if step.step_type == :step_sleep && is_nil(state), do: %{}, else: state
                  else
                    state
                  end

                next = if is_nil(state), do: step, else: nil
                state = if is_nil(state), do: state_data, else: state_data |> Map.merge(state)

                acc
                |> Map.put(:state_data, state)
                |> Map.put(:next, next)
            end

          _ ->
            acc
        end
      end)

    fn_arg = %{event: event, data: state_data}
    exec(next, fn_arg)
  end

  # Nothing left to run, return as completed
  defp exec(nil, %{data: data}), do: {200, data}

  defp exec(%{step_type: :step_run} = step, args) do
    op = UnhashedOp.from_step(step)

    # Invoke the step function
    case apply(step.mod, step.id, [args]) do
      # TODO: Allow also simple :ok and use existing map data
      {:ok, result} ->
        opcode = %GeneratorOpCode{
          id: UnhashedOp.hash(op),
          name: step.name,
          op: op.op,
          data: result
        }

        {206, [opcode]}

      {:error, error} ->
        {400, error}
    end
  end

  defp exec(%{step_type: :step_sleep} = step, _args) do
    op = UnhashedOp.from_step(step)

    opcode = %GeneratorOpCode{
      id: UnhashedOp.hash(op),
      name: step.name,
      op: op.op
    }

    {206, [opcode]}
  end

  defp exec(%{step_type: :exec_run} = step, args) do
    case apply(step.mod, step.id, [args]) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  # This shouldn't be executed
  defp exec(_, %{data: data}),
    do:
      {400,
       %{
         error: "unexpected execution occurred",
         data: data
       }}
end
