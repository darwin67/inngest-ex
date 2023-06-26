defmodule Inngest.Function.Args do
  @moduledoc """
  A struct representing arguments passed to functions
  """

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
