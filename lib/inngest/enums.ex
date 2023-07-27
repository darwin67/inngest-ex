defmodule Inngest.Enums do
  @moduledoc false

  @type opcode() :: binary()

  @spec opcode(atom()) :: binary()
  def opcode(:step_run), do: "Step"
  def opcode(:step_planned), do: "StepPlanned"
  def opcode(:step_sleep), do: "Sleep"
  def opcode(:step_wait_for_event), do: "WaitForEvent"
  def opcode(_), do: "None"
end
