defmodule Inngest.FnOpts do
  @moduledoc false

  defstruct [
    :id,
    :name,
    :debounce,
    :batch_events,
    retries: 3
  ]

  alias Inngest.Util

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

  @spec validate_debounce(t(), map()) :: map()
  def validate_debounce(fnopts, config) do
    case fnopts |> Map.get(:debounce) do
      nil ->
        config

      debounce ->
        period = Map.get(debounce, :period)

        if is_nil(period) do
          raise Inngest.InvalidDebounceConfigError
        end

        case Util.parse_duration(period) do
          {:error, error} ->
            raise Inngest.InvalidDebounceConfigError, message: error

          {:ok, seconds} ->
            if seconds > 7 * Util.day_in_seconds() do
              raise Inngest.InvalidDebounceConfigError,
                message: "cannot specify period for more than 7 days"
            end
        end

        Map.put(config, :debounce, debounce)
    end
  end
end
