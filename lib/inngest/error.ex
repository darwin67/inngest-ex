defmodule Inngest.Error do
  @moduledoc """
  A generic Inngest Error.
  Used to format errors into a structure that can be parsed by the UI
  """

  defstruct [:error, stack: nil]
end

defimpl Jason.Encoder, for: Inngest.Error do
  def encode(value, opts) do
    error = Map.get(value, :error)
    stacktrace = Exception.format(:error, error, Map.get(value, :stack))

    %{name: error.__struct__, message: error.message, stack: stacktrace}
    |> Jason.Encode.map(opts)
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
