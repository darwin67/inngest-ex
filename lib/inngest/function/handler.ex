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
    {200, %{status: "completed", result: "no steps detected"}}
  end

  # Initial invoke when stack list is empty
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
        %{
          event: event,
          params: %{
            "ctx" => %{"stack" => %{"stack" => stack}},
            "steps" => data
          }
        } = _args
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
            UnhashedOp.from_step(step)
            |> UnhashedOp.hash()

          if Map.has_key?(data, hash) do
            state_data = Map.get(data, hash)

            # TODO: remove this ignore comment
            # credo:disable-for-next-line
            if step.step_type == :step_sleep && is_nil(state_data) do
              %{step | state: %{}}
            else
              %{step | state: state_data}
            end
          else
            step
          end
        end)

      state_data =
        Enum.reduce(steps, %{}, fn s, acc ->
          # TODO: remove this ignore comment
          # credo:disable-for-next-line
          if is_nil(s.state), do: acc, else: Map.merge(acc, s.state)
        end)

      next = Enum.find(steps, fn step -> is_nil(step.state) end)

      case next.step_type do
        :step_run ->
          fn_arg = %{event: event, data: state_data}
          exec_step(next, fn_arg)

        :step_sleep ->
          exec_sleep(next)

        _ ->
          {200, "done"}
      end
    end
  end

  defp exec_step(step, args) do
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

  defp exec_sleep(step) do
    op = UnhashedOp.from_step(step)

    opcode = %GeneratorOpCode{
      id: UnhashedOp.hash(op),
      name: step.name,
      op: op.op
    }

    {206, [opcode]}
  end
end
