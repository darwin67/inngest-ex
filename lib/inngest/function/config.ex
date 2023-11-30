defmodule Inngest.FnOpts do
  @moduledoc """
  Function configuration options.

  See the typespec for all available options.
  """

  defstruct [
    :id,
    :name,
    :debounce,
    :priority,
    :batch_events,
    :rate_limit,
    :idempotency,
    :concurrency,
    :cancel_on,
    retries: 3
  ]

  alias Inngest.Util

  @type t() :: %__MODULE__{
          id: id(),
          name: name(),
          retries: retries(),
          debounce: debounce(),
          priority: priority(),
          batch_events: batch_events(),
          rate_limit: rate_limit(),
          idempotency: idempotency(),
          concurrency: concurrency(),
          cancel_on: cancel_on()
        }

  @typedoc """
  A unique identifier for your function. This should not change between deploys.
  """
  @type id() :: binary()

  @typedoc """
  A name for your function. If defined, this will be shown in the UI as a friendly display name instead of the ID.
  """
  @type name() :: binary() | nil

  @typedoc """
  Configure the number of times the function will be retried from `0` to `20`. Default: `3`
  """
  @type retries() :: number() | nil

  @typedoc """
  Options to configure function debounce ([reference](https://www.inngest.com/docs/reference/functions/debounce)).

  **period** - `string` required

  The time period of which to set the limit. The period begins when the first matching event is received. How long to wait before invoking the function with the batch even if it's not full. Current permitted values are from `1s` to `7d (168h)`.

  **key** - `string` optional

  A unique key expression to apply the debounce to. The expression is evaluated for each triggering event.

  Expressions are defined using the [Common Expression Language (CEL)](https://github.com/google/cel-go) with the original event accessible using dot-notation. Examples:

  * Debounce per customer id: `event.data.customer_id`
  * Debounce per account and email address: `event.data.account_id + "-" + event.user.email`
  """
  @type debounce() ::
          %{
            key: binary() | nil,
            period: binary()
          }
          | nil

  @typedoc """
  Prioritize specific function runs ahead of others ([reference](https://www.inngest.com/docs/reference/functions/run-priority))

  **run** - `string` optional

  An expression which must return an integer between -600 and 600 (by default), with higher return values resulting in a higher priority.
  See [reference](https://www.inngest.com/docs/reference/functions/run-priority) for more information.
  """
  @type priority() ::
          %{
            run: binary() | nil
          }
          | nil

  @typedoc """
  Configure how the function should consume batches of events ([reference](https://www.inngest.com/docs/guides/batching))

  **max_size** - `number` required

  The maximum number of events a batch can have. Current limit is `100`.

  **timeout** - `string` required

  How long to wait before invoking the function with the batch even if it's not full.
  Current permitted values are from `1s` to `60s`.
  """
  @type batch_events() ::
          %{
            max_size: number(),
            timeout: binary()
          }
          | nil

  @typedoc """
  Options to configure how to rate limit function execution ([reference](https://www.inngest.com/docs/reference/functions/rate-limit))

  **limit** - `number` required

  The maximum number of functions to run in the given time period.

  **period** - `number` required

  The time period of which to set the limit. The period begins when the first matching event is received.
  How long to wait before invoking the function with the batch even if it's not full.
  Current permitted values are from `1s` to `60s`.

  **key** - `string` optional

  A unique key expression to apply the limit to. The expression is evaluated for each triggering event.

  Expressions are defined using the [Common Expression Language (CEL)](https://github.com/google/cel-go) with the original event accessible using dot-notation. Examples:

  * Rate limit per customer id: `event.data.customer_id`
  * Rate limit per account and email address: `event.data.account_id + "-" + event.user.email`

  ### Note

  This option cannot be used with `cancel_on` and `rate_limit`.
  """
  @type rate_limit() ::
          %{
            limit: number(),
            period: binary(),
            key: binary() | nil
          }
          | nil

  @typedoc """
  A key expression which is used to prevent duplicate events from triggering a function more than once in 24 hours.

  This is equivalent to setting `rate_limit` with a `key`, a limit of `1` and period of `24hr`.

  Expressions are defined using the [Common Expression Language (CEL)](https://github.com/google/cel-go) with the original event accessible using dot-notation. Examples:

  * Only run once for each customer id: `event.data.customer_id`
  * Only run once for each account and email address: `event.data.account_id + "-" + event.user.email`

  """
  @type idempotency() :: binary() | nil

  @typedoc """
  Limit the number of concurrently running functions ([reference](https://www.inngest.com/docs/functions/concurrency))

  **limit** - `string` required

  The maximum number of concurrently running steps.

  **key** - `string` optional

  A unique key expression for which to restrict concurrently running steps to. The expression is evaluated for each triggering event and a unique key is generate.
  """
  @type concurrency() :: number() | concurrency_option() | list(concurrency_option()) | nil
  @type concurrency_option() ::
          %{
            limit: number(),
            key: binary() | nil,
            scope: binary() | nil
          }
          | nil
  @concurrency_scopes ["fn", "env", "account"]

  @typedoc """
  Define an event that can be used to cancel a running or sleeping function ([reference](https://www.inngest.com/docs/functions/cancellation))

  **event** - `string` required

  The event name which will be used to cancel

  **match** - `string` optional

  The property to match the event trigger and the cancelling event, using dot-notation
  e.g. `data.userId`

  **if** - `string` optional

  TODO

  **timeout** - `string` optional

  The amount of time to wait to receive the cancelling event.
  e.g. `30m`, `3h`, or `2d`
  """
  @type cancel_on() :: cancel_option() | list(cancel_option()) | nil

  @type cancel_option() :: %{
          event: binary(),
          match: binary() | nil,
          if: binary() | nil,
          timeout: binary() | nil
        }

  @doc false
  @spec validate_debounce(t(), map()) :: map()
  def validate_debounce(fnopts, config) do
    case fnopts |> Map.get(:debounce) do
      nil ->
        config

      debounce ->
        period = Map.get(debounce, :period)

        if is_nil(period) do
          raise Inngest.DebounceConfigError, message: "'period' must be set for debounce"
        end

        case Util.parse_duration(period) do
          {:error, error} ->
            raise Inngest.DebounceConfigError, message: error

          {:ok, seconds} ->
            # credo:disable-for-next-line
            if seconds > 7 * Util.day_in_seconds() do
              raise Inngest.DebounceConfigError,
                message: "cannot specify period for more than 7 days"
            end
        end

        Map.put(config, :debounce, debounce)
    end
  end

  @doc false
  @spec validate_priority(t(), map()) :: map()
  def validate_priority(fnopts, config) do
    case fnopts |> Map.get(:priority) do
      nil ->
        config

      %{} = priority ->
        run = Map.get(priority, :run)

        if !is_nil(run) && !is_binary(run) do
          raise Inngest.PriorityConfigError, message: "invalid priority run: '#{run}'"
        end

        Map.put(config, :priority, priority)

      rest ->
        raise Inngest.PriorityConfigError, message: "invalid priority config: '#{rest}'"
    end
  end

  @doc false
  @spec validate_batch_events(t(), map()) :: map()
  # credo:disable-for-next-line
  def validate_batch_events(fnopts, config) do
    case fnopts |> Map.get(:batch_events) do
      nil ->
        config

      batch ->
        max_size = Map.get(batch, :max_size)
        timeout = Map.get(batch, :timeout)

        if is_nil(max_size) || is_nil(timeout) do
          raise Inngest.BatchEventConfigError,
            message: "'max_size' and 'timeout' must be set for batch_events"
        end

        rate_limit = Map.get(fnopts, :rate_limit)
        cancel_on = Map.get(fnopts, :cancel_on)

        if !is_nil(rate_limit) do
          raise Inngest.BatchEventConfigError,
            message: "'rate_limit' cannot be used with event_batches"
        end

        if !is_nil(cancel_on) do
          raise Inngest.BatchEventConfigError,
            message: "'cancel_on' cannot be used with event_batches"
        end

        case Util.parse_duration(timeout) do
          {:error, error} ->
            raise Inngest.BatchEventConfigError, message: error

          {:ok, seconds} ->
            # credo:disable-for-next-line
            if seconds < 1 || seconds > 60 do
              raise Inngest.BatchEventConfigError,
                message: "'timeout' duration set to '#{timeout}', needs to be 1s - 60s"
            end
        end

        batch = %{maxSize: max_size, timeout: timeout}
        Map.put(config, :batchEvents, batch)
    end
  end

  @doc false
  @spec validate_rate_limit(t(), map()) :: map()
  def validate_rate_limit(fnopts, config) do
    case fnopts |> Map.get(:rate_limit) do
      nil ->
        config

      rate_limit ->
        limit = Map.get(rate_limit, :limit)
        period = Map.get(rate_limit, :period)

        if is_nil(limit) || is_nil(period) do
          raise Inngest.RateLimitConfigError,
            message: "'limit' and 'period' must be set for rate_limit"
        end

        case Util.parse_duration(period) do
          {:error, error} ->
            raise Inngest.RateLimitConfigError, message: error

          {:ok, seconds} ->
            # credo:disable-for-next-line
            if seconds < 1 || seconds > 60 do
              raise Inngest.RateLimitConfigError,
                message: "'period' duration set to '#{period}', needs to be 1s - 60s"
            end
        end

        Map.put(config, :rateLimit, rate_limit)
    end
  end

  @doc false
  @spec validate_idempotency(t(), map()) :: map()
  def validate_idempotency(fnopts, config) do
    # NOTE: nothing really to validate, just have this for the sake of consistency
    case fnopts |> Map.get(:idempotency) do
      nil ->
        config

      setting ->
        if !is_binary(setting) do
          raise Inngest.IdempotencyConfigError, message: "idempotency must be a CEL string"
        end

        Map.put(config, :idempotency, setting)
    end
  end

  @doc false
  @spec validate_concurrency(t(), map()) :: map()
  def validate_concurrency(fnopts, config) do
    case fnopts |> Map.get(:concurrency) do
      nil ->
        config

      %{} = setting ->
        validate_concurrency(setting)
        Map.put(config, :concurrency, setting)

      [_ | _] = settings ->
        Enum.each(settings, &validate_concurrency/1)
        Map.put(config, :concurrency, settings)

      setting ->
        if is_number(setting) do
          Map.put(config, :concurrency, setting)
        else
          raise Inngest.ConcurrencyConfigError, message: "invalid concurrency setting"
        end
    end
  end

  defp validate_concurrency(%{} = setting) do
    limit = Map.get(setting, :limit)
    scope = Map.get(setting, :scope)

    if is_nil(limit) do
      raise Inngest.ConcurrencyConfigError, message: "'limit' must be set for concurrency"
    end

    if !is_nil(scope) && !Enum.member?(@concurrency_scopes, scope) do
      raise Inngest.ConcurrencyConfigError,
        message: "invalid scope '#{scope}', needs to be \"fn\"|\"env\"|\"account\""
    end
  end

  @doc false
  @spec validate_cancel_on(t(), map()) :: map()
  def validate_cancel_on(fnopts, config) do
    case fnopts |> Map.get(:cancel_on) do
      nil ->
        config

      %{} = settings ->
        validate_cancel_on(settings)
        Map.put(config, :cancel, [settings])

      [_ | _] = settings ->
        if Enum.count(settings) > 5 do
          raise Inngest.CancelConfigError,
            message: "cannot have more than 5 cancellation triggers"
        end

        Enum.each(settings, &validate_cancel_on/1)
        Map.put(config, :cancel, settings)

      rest ->
        raise Inngest.CancelConfigError, message: "invalid cancellation config: '#{rest}'"
    end
  end

  defp validate_cancel_on(%{} = settings) do
    event = Map.get(settings, :event)
    timeout = Map.get(settings, :timeout)

    if is_nil(event) do
      raise Inngest.CancelConfigError, message: "'event' must be set for cancel_on"
    end

    if !is_nil(timeout) do
      # credo:disable-for-next-line
      case Util.parse_duration(timeout) do
        {:error, error} ->
          raise Inngest.CancelConfigError, message: error

        {:ok, _} ->
          nil
      end
    end
  end
end
