defmodule Inngest.FnOpts do
  @moduledoc false

  defstruct [
    :id,
    :name,
    :debounce,
    :batch_events,
    retries: 3
  ]

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          retries: number() | nil,
          debounce: debounce() | nil,
          batch_events: batch_events() | nil
        }

  @type debounce() :: %{
          key: nil | binary(),
          period: binary()
        }

  @type batch_events() :: %{
          max_size: number(),
          timeout: binary()
        }

  # @spec validate_debounce(t()) :: map()
  # def validate_debounce(fnopts) do
  # end
end
