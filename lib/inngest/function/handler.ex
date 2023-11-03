defmodule Inngest.Function.Handler do
  @moduledoc """
  A struct that keeps info about function, and
  handles the invoking of steps
  """
  alias Inngest.Function.{UnhashedOp, GeneratorOpCode}

  @doc """
  Handles the invoking of steps and runs from the executor
  """
  @spec invoke(Inngest.V1.Function, map()) :: {200 | 206 | 400 | 500, map()}
  def invoke(mod, args) do
    case mod.run(args) do
      {:ok, val} -> {200, val}
      {:error, val} -> {400, val}
    end
  end

  # Nothing left to run, return as completed
  defp exec(nil, %{data: data}), do: {200, data}

  defp exec(%{step_type: :step_run} = step, args) do
    op = UnhashedOp.from_step(step)

    # Invoke the step function
    case apply(step.mod, step.id, [args]) do
      :ok ->
        opcode = %GeneratorOpCode{
          id: UnhashedOp.hash(op),
          name: step.name,
          op: op.op,
          data: nil
        }

        {206, [opcode]}

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
