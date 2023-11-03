defmodule Inngest.Handler do
  @moduledoc false

  defstruct [
    :event,
    :events,
    :step,
    :run_id,
    # :logger, # TODO?
    :attempt
  ]

  @type t() :: %__MODULE__{
          event: Inngest.Event.t(),
          events: [Inngest.Event.t()],
          step: Inngest.StepTool,
          run_id: binary(),
          attempt: number()
        }

  @spec invoke(t(), Inngest.Function) :: {200 | 206 | 400 | 500, map()}
  def invoke(handler, mod) do
    case mod.exec(handler) do
      {:ok, val} -> {200, val}
      {:error, val} -> {400, val}
    end
  end
end
