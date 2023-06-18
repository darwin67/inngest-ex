defmodule Inngest.Function.Trigger do
  @moduledoc false

  @derive Jason.Encoder
  defstruct [
    :event,
    :expression,
    :cron
  ]

  @type t() :: %__MODULE__{
          # requires `event` and optionaly `expression` for event triggers
          event: binary() | nil,
          expression: binary() | nil,

          # requires `cron` for cron triggers
          cron: binary() | nil
        }
end
