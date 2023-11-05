defmodule Inngest.StepTool do
  @moduledoc false

  alias Inngest.Function.{Context, UnhashedOp, GeneratorOpCode}

  @type id() :: binary()
  @type datetime() :: binary() | DateTime.t() | Date.t() | NaiveDateTime.t()

  @spec run(Context.t(), id(), fun()) :: any()
  def run(%{steps: steps} = _ctx, step_id, func) do
    op = %UnhashedOp{name: step_id, op: "Step"}
    hashed_id = UnhashedOp.hash(op)

    # check for hash
    case Map.get(steps, hashed_id) do
      nil ->
        # if not, execute function
        result = func.()

        # cancel execution and return with opcode
        throw(%GeneratorOpCode{
          id: hashed_id,
          name: step_id,
          display_name: step_id,
          op: op.op,
          data: result
        })

      # if found, return value
      val ->
        val
    end
  end

  @spec sleep(Context.t(), id(), binary()) :: nil
  def sleep(%{steps: steps} = _ctx, step_id, duration) do
    op = %UnhashedOp{name: step_id, op: "Sleep"}
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
      throw(%GeneratorOpCode{
        id: hashed_id,
        name: duration,
        display_name: step_id,
        op: op.op,
        data: nil
      })
    end
  end

  @spec sleep_until(Context.t(), id(), datetime()) :: nil
  def sleep_until(%{steps: steps} = _ctx, step_id, time) do
    op = %UnhashedOp{name: step_id, op: "Sleep"}
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
      case Inngest.Function.validate_datetime(time) do
        {:ok, datetime} ->
          throw(%GeneratorOpCode{
            id: hashed_id,
            name: datetime,
            op: op
          })

        {:error, error} ->
          {:error, error}
      end
    end
  end

  def wait_for_event() do
  end

  def send_event() do
  end
end
