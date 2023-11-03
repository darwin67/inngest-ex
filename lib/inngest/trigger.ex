defmodule Inngest.Trigger do
  @moduledoc """
  Struct representing a function trigger.

  Can either be an `event` or a `cron`, and they're mutually exclusive.

  ## Examples

      # defining an event trigger
      %Inngest.Trigger{event: "auth/signup.email"}

      # defining a cron trigger, and can accept a timezone
      %Inngest.Trigger{cron: "TZ=America/Los_Angeles * * * * *"}
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

defimpl Jason.Encoder, for: Inngest.Trigger do
  def encode(%{cron: cron} = value, opts) when is_binary(cron) do
    Jason.Encode.map(Map.take(value, [:cron]), opts)
  end

  def encode(value, opts) do
    Jason.Encode.map(Map.take(value, [:event, :expression]), opts)
  end
end
