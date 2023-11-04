defmodule Inngest.Handler do
  @moduledoc false

  defstruct [
    :ctx,
    :event,
    :events,
    :step,
    :run_id,
    # :logger, # TODO?
    :attempt
  ]

  @type t() :: %__MODULE__{
          ctx: map(),
          event: Inngest.Event.t(),
          events: [Inngest.Event.t()],
          step: Inngest.StepTool,
          run_id: binary(),
          attempt: number()
        }
end

defmodule Inngest.Handler.Context do
  defstruct [
    :attempt,
    :disable_immediate_execution,
    :env,
    :fn_id,
    :run_id,
    :stack,
    :use_api
  ]

  @type t() :: %__MODULE__{
          attempt: number(),
          disable_immediate_execution: boolean(),
          env: binary(),
          fn_id: binary(),
          run_id: binary(),
          stack: map(),
          use_api: boolean()
        }
end
