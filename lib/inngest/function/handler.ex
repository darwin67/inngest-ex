defmodule Inngest.Function.Handler do
  @moduledoc """
  A struct that keeps info about function, and
  handles the invoking of steps
  """
  alias Inngest.Enums
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
  def invoke(%{steps: []} = _handler, _params) do
    {200, %{status: "completed", result: "no steps"}}
  end

  def invoke(
        %{steps: steps} = _handler,
        %{event: event, params: %{"ctx" => %{"stack" => %{"stack" => []}}}} = _args
      ) do
    [step | _] = steps
    fn_arg = %{event: event, data: %{}}
    exec_step(step, fn_arg)
  end

  def invoke(
        %{steps: steps} = _handler,
        %{event: event, params: %{"ctx" => %{"stack" => %{"stack" => stack}}, "steps" => data}} =
          _args
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
            %UnhashedOp{name: step.name, op: Enums.opcode(:step_run)}
            |> UnhashedOp.hash()

          %{step | state: Map.get(data, hash)}
        end)

      state_data =
        Enum.reduce(steps, %{}, fn s, acc ->
          # TODO: remove this ignore comment
          # credo:disable-for-next-line
          if is_nil(s.state), do: acc, else: Map.merge(acc, s.state)
        end)

      next = Enum.find(steps, fn step -> is_nil(step.state) end)
      fn_arg = %{event: event, data: state_data}
      exec_step(next, fn_arg)
    end
  end

  defp exec_step(step, args) do
    unhashed_op = %UnhashedOp{
      name: step.name,
      op: Enums.opcode(:step_run)
    }

    # Invoke the step function
    case apply(step.mod, step.id, [args]) do
      # TODO: Allow also simple :ok and use existing map data
      {:ok, result} ->
        opcode = %GeneratorOpCode{
          id: UnhashedOp.hash(unhashed_op),
          name: step.name,
          op: Enums.opcode(:step_run),
          opts: %{},
          data: result
        }

        {206, [opcode]}

      {:error, error} ->
        {400, error}
    end
  end
end
