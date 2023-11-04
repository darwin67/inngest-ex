defmodule Inngest.StepTool do
  @moduledoc false

  alias Inngest.Function.{UnhashedOp, GeneratorOpCode}

  @type id() :: binary()

  @spec run(map(), id(), fun()) :: nil
  def run(ctx, step_id, func) do
    op = %UnhashedOp{name: step_id, op: "Step"}
    hashed_id = UnhashedOp.hash(op)

    # check for hash
    case ctx |> Map.get(:steps, %{}) |> Map.get(hashed_id) do
      nil ->
        # if not, execute function
        result = func.()

        opcode = %GeneratorOpCode{
          id: hashed_id,
          name: step_id,
          display_name: step_id,
          op: op.op,
          data: result
        }

        # cancel execution and return
        throw(opcode)

      # if found, return value
      val ->
        val
    end
  end

  def sleep() do
  end

  def sleep_until() do
  end

  def wait_for_event() do
  end

  def send_event() do
  end
end
