defmodule Inngest.StepTool do
  @moduledoc false

  @type id() :: binary()

  @spec run(map(), id(), fun()) :: nil
  def run(ctx, _step_id, func) do
    ctx |> IO.inspect()

    # check for hash
    # if found, return value

    # if not, execute function
    func.()
    # cancel execution and return
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
