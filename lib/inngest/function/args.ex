defmodule Inngest.Function.Args do
  defstruct [
    :run_id,
    :event,
    events: []
  ]

  @type t() :: %__MODULE__{
          run_id: binary(),
          event: map(),
          events: [map()]
        }
end
