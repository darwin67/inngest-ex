defmodule Inngest.StepTool do
  @moduledoc false

  @type id() :: binary()

  @spec run(id(), fun()) :: nil
  def run(_step_id, func) do
    func.()
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
