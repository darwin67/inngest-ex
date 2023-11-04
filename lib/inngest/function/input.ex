defmodule Inngest.Function.Input do
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
end

defmodule Inngest.Function.Context do
  defstruct [
    :attempt,
    :run_id,
    :stack,
    :steps
  ]

  @type t() :: %__MODULE__{
          attempt: number(),
          run_id: binary(),
          stack: map(),
          steps: map()
        }
end
