defmodule Inngest.Function.Trigger do
  @moduledoc """
  Struct representing a function trigger.
  Can either be an event or a cron.
  """

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

defimpl Jason.Encoder, for: Inngest.Function.Trigger do
  def encode(%{cron: cron} = value, opts) when is_binary(cron) do
    Jason.Encode.map(Map.take(value, [:cron]), opts)
  end

  def encode(value, opts) do
    Jason.Encode.map(Map.take(value, [:event, :expression]), opts)
  end
end
