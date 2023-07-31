defmodule Inngest.Function.Handler do
  @moduledoc """
  A struct that keeps info about function, and
  handles the invoking of steps
  """
  alias Inngest.Function.{Step, UnhashedOp, GeneratorOpCode, Handler}

  defstruct [:mod, :file, :steps]

  @type t() :: %__MODULE__{
          mod: module(),
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
          params: %{
            "ctx" => %{
              "stack" => %{
                "current" => _current,
                "stack" => stack
              }
            },
            "steps" => data
          }
        } = _args
      ) do
    %{state_data: state_data, next: next} =
      steps
      |> Enum.reduce(%{state_data: %{}, next: nil, idx: 0}, fn step, acc ->
        %{state_data: state_data, next: next, idx: idx} = acc

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
                  if hash == Enum.at(stack, idx) do
                    # credo:disable-for-next-line
                    case step.step_type do
                      # credo:disable-for-next-line
                      :step_sleep ->
                        # credo:disable-for-next-line
                        if is_nil(state), do: %{}, else: state

                      # credo:disable-for-next-line
                      :step_wait_for_event ->
                        # credo:disable-for-next-line
                        %{step.name => state}

                      _ ->
                        state
                    end
                  else
                    state
                  end

                # use step name as key if cached state is not a map value
                state =
                  if !is_nil(state) && !is_map(state) do
                    %{step.name => state}
                  else
                    state
                  end

                next = if is_nil(state), do: step, else: nil
                state = if is_nil(state), do: state_data, else: state_data |> Map.merge(state)

                acc
                |> Map.put(:state_data, state)
                |> Map.put(:next, next)
                |> Map.put(:idx, idx + 1)
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

  defp exec(%{step_type: :step_sleep, tags: %{execute: true}} = step, args) do
    op = UnhashedOp.from_step(step)

    # Invoke the content to get the value for sleep
    case apply(step.mod, step.id, [args]) |> Inngest.Function.validate_datetime() do
      {:ok, datetime} ->
        opcode = %GeneratorOpCode{
          id: UnhashedOp.hash(op),
          name: datetime,
          op: op.op
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

  defp exec(%{step_type: :step_wait_for_event} = step, args) do
    op = UnhashedOp.from_step(step)

    opts =
      apply(step.mod, step.id, [args])
      |> Enum.reduce(%{}, fn
        {key, value}, acc -> Map.put(acc, key, value)
        keyword, acc when is_list(keyword) -> Enum.into(keyword, acc)
      end)

    opts =
      cond do
        Map.get(opts, :match) ->
          match = Map.get(opts, :match)
          timeout = Map.get(opts, :timeout)
          %{timeout: timeout, if: "event.#{match} == async.#{match}"}

        Map.get(opts, :if) ->
          Map.take(opts, [:timeout, :if])

        true ->
          Map.take(opts, [:timeout])
      end

    opcode = %GeneratorOpCode{
      id: UnhashedOp.hash(op),
      name: step.name,
      op: op.op,
      opts: opts
    }

    {206, [opcode]}
  end

  defp exec(%{step_type: :exec_run} = step, args) do
    apply(step.mod, step.id, [args])
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
