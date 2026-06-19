defmodule Inngest.Error do
  @moduledoc """
  A generic Inngest Error.
  Used to format errors into a structure that can be parsed by the UI
  """

  defstruct [:error, stack: nil]
end

defmodule Inngest.StepError do
  @moduledoc """
  Error raised when a memoized step contains a final serialized error.
  """
  defexception [:message, :payload]

  @impl true
  def exception(payload) when is_map(payload) do
    payload = normalize_payload(payload)
    message = Map.get(payload, :message, "step failed")

    %__MODULE__{message: message, payload: payload}
  end

  def exception(message) when is_binary(message) do
    payload = %{name: "Inngest.StepError", message: message}

    %__MODULE__{message: message, payload: payload}
  end

  defp normalize_payload(payload) do
    payload
    |> get_payload_value(:name, "Inngest.StepError")
    |> get_payload_value(:message, "step failed")
    |> maybe_payload_value(payload, :stack)
  end

  defp get_payload_value(payload, key, default) do
    Map.put(payload, key, Map.get(payload, key) || Map.get(payload, Atom.to_string(key), default))
  end

  defp maybe_payload_value(acc, payload, key) do
    case Map.get(payload, key) || Map.get(payload, Atom.to_string(key)) do
      nil -> acc
      value -> Map.put(acc, key, value)
    end
  end
end

defimpl Jason.Encoder, for: Inngest.Error do
  def encode(value, opts) do
    error = Map.get(value, :error)

    error
    |> encode_error(Map.get(value, :stack))
    |> Jason.Encode.map(opts)
  end

  defp encode_error(%Inngest.StepError{payload: payload}, _stacktrace), do: payload

  defp encode_error(error, stacktrace) do
    stacktrace = Exception.format(:error, error, stacktrace)

    %{name: error.__struct__, message: error.message, stack: stacktrace}
  end
end

defmodule Inngest.NonRetriableError do
  @moduledoc """
  Error signaling to not retry
  """
  defexception message: "Not retrying error. Exiting."
end

defmodule Inngest.RetryAfterError do
  @moduledoc """
  Error to control how long to wait before attempting a retry

  ### NOTE
  This works with retry `attempts` and will not exceed the set `attempts`.
  """
  defexception [:message, seconds: 3]
end

defmodule Inngest.DebounceConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `debounce`.
  """
  defexception [:message]
end

defmodule Inngest.BatchEventConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `batch_events`.
  """
  defexception [:message]
end

defmodule Inngest.RateLimitConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `rate_limit`.
  """
  defexception [:message]
end

defmodule Inngest.ThrottleConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `throttle`.
  """
  defexception [:message]
end

defmodule Inngest.SingletonConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `singleton`.
  """
  defexception [:message]
end

defmodule Inngest.TimeoutConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `timeouts`.
  """
  defexception [:message]
end

defmodule Inngest.ConcurrencyConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `concurrency`.
  """
  defexception [:message]
end

defmodule Inngest.IdempotencyConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `idempotency`.
  """
  defexception [:message]
end

defmodule Inngest.CancelConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `cancel_on`.
  """
  defexception [:message]
end

defmodule Inngest.PriorityConfigError do
  @moduledoc """
  Error indicating there's a misconfiguration when attempting to use `priority`.
  """
  defexception [:message]
end
