defmodule Inngest.Function.Handler do
  @moduledoc """
  A struct that keeps info about function, and
  handles the invoking of steps
  """
  alias Inngest.Function.{Step, OpCode, UnhashedOp, GeneratorOpCode}

  defstruct [:name, :file, :steps]

  @type t() :: %__MODULE__{
          name: module(),
          file: binary(),
          steps: [Step.t()]
        }

  def invoke(%{steps: []} = _handler, _params) do
    {200, %{status: "completed", result: "no steps"}}
  end

  def invoke(%{steps: steps} = _handler, %{"ctx" => %{"stack" => %{"stack" => []}}} = params) do
    IO.inspect(params)

    [step | _] = steps
    op = OpCode.enum(:step_run)

    unhashed_op = %UnhashedOp{
      name: step.name,
      op: op
    }

    result = apply(step.mod, step.id, [%{}])

    opcode = %GeneratorOpCode{
      id: UnhashedOp.hash(unhashed_op),
      name: step.name,
      op: op,
      opts: %{},
      data: result
    }

    {206, [opcode]}
  end

  def invoke(
        %{steps: steps} = _handler,
        %{"ctx" => %{"stack" => %{"stack" => stack}}, "steps" => data} = _params
      ) do
    total_steps = Enum.count(steps)
    executed_steps = Enum.count(stack)

    if executed_steps == total_steps do
      {200, %{status: "completed"}}
    else
      steps =
        steps
        |> Enum.map(fn step ->
          hash =
            %UnhashedOp{name: step.name, op: OpCode.enum(:step_run)}
            |> UnhashedOp.hash()

          %{step | state: Map.get(data, hash)}
        end)

      next = Enum.find(steps, fn step -> is_nil(step.state) end)

      unhashed_op = %UnhashedOp{
        name: next.name,
        op: OpCode.enum(:step_run)
      }

      result = apply(next.mod, next.id, [%{}])

      opcode = %GeneratorOpCode{
        id: UnhashedOp.hash(unhashed_op),
        name: next.name,
        op: OpCode.enum(:step_run),
        opts: %{},
        data: result
      }

      {206, [opcode]}
    end
  end
end
