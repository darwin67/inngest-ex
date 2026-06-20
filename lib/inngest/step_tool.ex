defmodule Inngest.StepTool do
  @moduledoc """
  Durable step helpers available as `input.step` inside an Inngest function.

  Steps split function work into durable units that can be retried and memoized
  by Inngest. Step IDs are hashed with SHA-1 before they are reported to the
  executor. When the same step ID appears more than once in a function, the SDK
  appends `:1`, `:2`, and so on before hashing each repeated occurrence.

  ## Reporting

  | SDK call | Reported opcode | Notes |
  |----------|-----------------|-------|
  | `run/3` | `StepRun` | Used when immediate execution is allowed and the step body runs in the current call request. Includes `data`, even when the result is `nil`. |
  | `run/4` | `StepRun` | Same as `run/3`, with replay options such as `keys: :atoms`. |
  | `run/3` | `StepPlanned` | Used when `ctx.disable_immediate_execution` prevents running the step body in the current call request. |
  | `run/3` | `StepError` | Used when an executed step body raises. Includes the serialized `error` payload. |
  | targeted `stepId` | `StepNotFound` | Returned when a targeted hashed step ID cannot be found during deterministic traversal. |
  | `sleep/3`, `sleep_until/3` | `Sleep` | Uses `opts.duration` for the duration or ISO timestamp. |
  | `wait_for_event/3` | `WaitForEvent` | Uses `opts` for event name, timeout, and matching expression. |
  | `invoke/3` | `InvokeFunction` | Uses the active client ID for module targets, plus `opts.payload` and optional `opts.timeout`. |
  | `send_event/3` | `StepRun` | Implemented as a durable run step around event sending with the active client. |

  ## Memoization

  Run and invoke-style steps memoize successful values as `%{"data" => value}`
  and failed values as `%{"error" => error}`. Successful values are unwrapped
  before being returned to user code. Failed memoized steps raise
  `Inngest.StepError`; if that error bubbles out of the function, the SDK returns
  it as a non-retriable function error.

  Sleep steps are memoized as `nil`. Wait-for-event steps are memoized as the
  received event payload or `nil` when the wait times out.

  Legacy raw run-step values are not supported by the spec-compliant
  memoization path. A raw memoized run-step value raises `Inngest.StepError` so
  payload shape problems fail clearly.

  ## Map Keys

  Freshly executed `run/3` results are returned exactly as user code returns
  them. Replayed memoized results come from JSON payloads, so map keys are
  strings by default:

      %{"foo" => "bar"} =
        step.run(ctx, "load", fn ->
          %{foo: "bar"}
        end)

  Use `run/4` with `keys: :atoms` when you need to pattern match on atom keys
  after replay:

      %{foo: "bar"} =
        step.run(ctx, "load", fn ->
          %{foo: "bar"}
        end, keys: :atoms)

  `keys: :atoms` converts string keys recursively with
  `String.to_existing_atom/1`. It will not create new atoms. If a memoized key
  does not already exist as an atom, the SDK raises `Inngest.StepError`.

  > #### Warning {: .warning}
  >
  > Atoms are not garbage collected by the Erlang VM. Creating too many atoms can
  > exhaust the atom table and crash the VM. The SDK intentionally avoids
  > creating atoms from arbitrary memoized JSON keys. Only use `keys: :atoms` for
  > known, bounded response shapes whose atom keys already exist in your
  > application.
  """

  alias Inngest.{Event, Middleware}
  alias Inngest.Function.{Context, UnhashedOp, GeneratorOpCode}

  @type id() :: binary()
  @type datetime() :: binary() | DateTime.t() | Date.t() | NaiveDateTime.t()
  @type run_opt() :: {:keys, :strings | :atoms}

  @doc """
  Runs a durable step.

  Fresh execution returns the value from `func` exactly as provided by user code.
  When the step has already been memoized, the SDK unwraps the executor payload
  from `%{"data" => value}` and returns `value` without reporting another
  opcode.

  Use `run/4` when replayed memoized map keys need to be converted to atoms.
  """
  @spec run(Context.t(), id(), fun()) :: any()
  def run(ctx, step_id, func), do: run(ctx, step_id, func, [])

  @doc """
  Runs a durable step with replay options.

  Supported options:

  | Option | Values | Default | Description |
  |--------|--------|---------|-------------|
  | `:keys` | `:strings`, `:atoms` | `:strings` | Controls map keys for replayed memoized `%{"data" => value}` payloads. |

  `keys: :atoms` recursively converts string keys using
  `String.to_existing_atom/1`. It does not create atoms and raises
  `Inngest.StepError` if a replayed key does not already exist as an atom.

  This option only applies to replayed memoized data. Freshly executed results
  are returned exactly as `func` returns them.
  """
  @spec run(Context.t(), id(), fun(), [run_opt()]) :: any()
  def run(%{steps: steps} = ctx, step_id, func, opts) do
    step_args =
      transform_step_input(ctx, %{
        ctx: ctx,
        step_id: step_id,
        step_type: "run",
        input: [],
        options: Map.new(opts),
        memoized: false
      })

    step_id = step_args.step_id
    opts = Map.to_list(step_args.options)
    op = UnhashedOp.new(ctx, "Step", step_id)
    hashed_id = UnhashedOp.hash(op)

    # Memoized steps must return without reporting another opcode. New steps
    # either execute immediately, plan, or produce StepNotFound for targets.
    case Map.get(steps, hashed_id) do
      nil -> report_run_step(ctx, hashed_id, step_id, func)
      val -> memoized_result!(ctx, hashed_id, val, opts)
    end
  end

  @doc """
  Pauses the function for a duration such as `"10s"`, `"5m"`, or `"1h"`.

  The SDK reports a `Sleep` opcode with `opts.duration`. Once the sleep is
  memoized by the executor, replay returns `nil`.
  """
  @spec sleep(Context.t(), id(), binary()) :: nil
  def sleep(%{steps: steps} = ctx, step_id, duration) do
    op = UnhashedOp.new(ctx, "Sleep", step_id)
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
      # A targeted request should never execute or report unrelated steps.
      maybe_step_not_found!(ctx, hashed_id)

      throw(%GeneratorOpCode{
        id: hashed_id,
        display_name: step_id,
        op: op.op,
        opts: %{duration: duration}
      })
    end
  end

  @doc """
  Pauses the function until a date or timestamp.

  Accepts a binary timestamp, `DateTime`, `Date`, or `NaiveDateTime`. The SDK
  validates and reports the timestamp as a `Sleep` opcode with `opts.duration`.
  Once memoized by the executor, replay returns `nil`.
  """
  @spec sleep_until(Context.t(), id(), datetime()) :: nil
  def sleep_until(%{steps: steps} = ctx, step_id, time) do
    op = UnhashedOp.new(ctx, "Sleep", step_id)
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
      maybe_step_not_found!(ctx, hashed_id)

      case Inngest.Function.validate_datetime(time) do
        {:ok, datetime} ->
          throw(%GeneratorOpCode{
            id: hashed_id,
            display_name: step_id,
            op: op.op,
            opts: %{duration: datetime}
          })

        {:error, error} ->
          {:error, error}
      end
    end
  end

  @doc """
  Waits for another event before continuing.

  Options may include:

  | Option | Description |
  |--------|-------------|
  | `:event` | Event name to wait for. |
  | `:timeout` | Maximum wait duration. |
  | `:if` | Spec expression used to match the incoming event. |
  | `:match` | Elixir shorthand that renders to `event.<match> == async.<match>`. |

  Replayed memoized values return an `Inngest.Event` when an event was received
  or `nil` when the wait timed out.
  """
  @spec wait_for_event(Context.t(), id(), map()) :: map()
  def wait_for_event(%{steps: steps} = ctx, step_id, opts) do
    op = UnhashedOp.new(ctx, "WaitForEvent", step_id, opts)
    hashed_id = UnhashedOp.hash(op)

    if steps |> Map.has_key?(hashed_id) do
      # Wait-for-event memoization is step-specific: nil means timeout and a
      # map means the received event payload.
      case steps |> Map.get(hashed_id) do
        nil -> nil
        event -> Event.from(event)
      end
    else
      maybe_step_not_found!(ctx, hashed_id)

      opts =
        opts
        |> Enum.reduce(%{}, fn
          {key, value}, acc -> Map.put(acc, key, value)
          keyword, acc when is_list(keyword) -> Enum.into(keyword, acc)
        end)

      # The Elixir API accepts :match as shorthand for the spec's if expression.
      opts =
        cond do
          Map.has_key?(opts, :match) ->
            match = Map.get(opts, :match)
            timeout = Map.get(opts, :timeout)
            event = Map.get(opts, :event)
            %{event: event, timeout: timeout, if: "event.#{match} == async.#{match}"}

          Map.has_key?(opts, :if) ->
            Map.take(opts, [:event, :timeout, :if])

          true ->
            Map.take(opts, [:event, :timeout])
        end

      throw(%GeneratorOpCode{
        id: hashed_id,
        name: Map.get(opts, :event, step_id),
        display_name: step_id,
        op: op.op,
        opts: opts
      })
    end
  end

  @doc """
  Invokes another Inngest function and waits for its result.

  Options include:

  | Option | Description |
  |--------|-------------|
  | `:function` | Function module to invoke. |
  | `:data` | Payload data for the invoked function. |
  | `:v` | Optional event payload version. |
  | `:timeout` | Optional timeout for the invocation. |

  New invocations report an `InvokeFunction` opcode. Replayed memoized results
  are unwrapped from `%{"data" => value}` or raised as `Inngest.StepError` from
  `%{"error" => error}`.

  When `:function` is a module, the reported function ID is built from the
  active `Inngest.Client` in the invocation context. This keeps step invokes
  aligned with the client used to register and serve functions.
  """
  @spec invoke(Context.t(), binary(), map()) :: map()
  def invoke(%{steps: steps} = ctx, step_id, opts) do
    op = UnhashedOp.new(ctx, "InvokeFunction", step_id, opts)
    hashed_id = UnhashedOp.hash(op)

    case Map.get(steps, hashed_id) do
      nil ->
        maybe_step_not_found!(ctx, hashed_id)

        # Invocation is reported to the executor. The invoked function's result
        # comes back later through the memoized action payload.
        func = Map.get(opts, :function)
        data = Map.get(opts, :data)
        timeout = Map.get(opts, :timeout)
        v = Map.get(opts, :v)

        generator_otps =
          if Map.has_key?(opts, :timeout) do
            %{
              function_id: function_id(ctx, func),
              payload: %{data: data, v: v},
              timeout: timeout
            }
          else
            %{
              function_id: function_id(ctx, func),
              payload: %{data: data, v: v}
            }
          end

        throw(%GeneratorOpCode{
          id: hashed_id,
          display_name: step_id,
          op: op.op,
          opts: generator_otps
        })

      val ->
        memoized_result!(ctx, hashed_id, val)
    end
  end

  @doc """
  Sends one or more events as a durable step.

  The event send is executed once, then reported as a `StepRun` containing the
  sent event IDs. Replayed memoized results return the stored event-send result
  without sending again.

  During function execution, sends use the active invocation client so event
  URL, event key, mode, and environment headers match the served app.
  """
  def send_event(%{steps: steps} = ctx, step_id, events) do
    step_args =
      transform_step_input(ctx, %{
        ctx: ctx,
        step_id: step_id,
        step_type: "sendEvent",
        input: [events],
        options: %{},
        memoized: false
      })

    step_id = step_args.step_id
    events = step_args.input |> List.wrap() |> List.first(events)
    op = UnhashedOp.new(ctx, "Step", step_id)
    hashed_id = UnhashedOp.hash(op)

    case Map.get(steps, hashed_id) do
      nil ->
        maybe_step_not_found!(ctx, hashed_id)

        display_name =
          if is_map(events) do
            Map.get(events, :name, step_id)
          else
            step_id
          end

        # Nested sends should use the same client as the invoked function so
        # event URLs, mode, env headers, and keys remain scoped to that app.
        {:ok, %{"ids" => event_ids, "status" => 200}} =
          execute_step(ctx, hashed_id, step_id, "sendEvent", fn ->
            send_events(ctx, events)
          end)

        # Sending events is durable only after the executor stores this StepRun.
        throw(%GeneratorOpCode{
          id: hashed_id,
          name: "sendEvent",
          display_name: "Send " <> display_name,
          op: "StepRun",
          data: %{event_ids: event_ids}
        })

      val ->
        memoized_result!(ctx, hashed_id, val)
    end
  end

  defp send_events(%{client: %Inngest.Client{} = client} = ctx, events) do
    Inngest.Client.send(client, events,
      middleware: Map.get(ctx, :middleware, client.middleware),
      context: %{ctx: ctx, function: Map.get(ctx, :function)}
    )
  end

  defp send_events(_ctx, events), do: Inngest.Client.send(events)

  defp function_id(%{client: %Inngest.Client{id: app_id}}, func), do: func.slug(app_id)
  defp function_id(_ctx, func), do: func.slug()

  @spec report_run_step(Context.t(), binary(), binary(), fun()) :: no_return()
  defp report_run_step(ctx, hashed_id, step_id, func) do
    cond do
      # The executor can ask for one specific hashed step ID. Only that step is
      # allowed to execute in this traversal.
      targeted_step?(ctx, hashed_id) ->
        execute_run_step(ctx, hashed_id, step_id, func)

      targeted_execution?(ctx) ->
        step_not_found!(ctx)

      # During discovery/planning, report the step without running user code.
      Map.get(ctx, :disable_immediate_execution, false) ->
        throw(%GeneratorOpCode{
          id: hashed_id,
          display_name: step_id,
          op: "StepPlanned"
        })

      true ->
        execute_run_step(ctx, hashed_id, step_id, func)
    end
  end

  @spec execute_run_step(Context.t(), binary(), binary(), fun()) :: no_return()
  defp execute_run_step(ctx, hashed_id, step_id, func) do
    result = execute_step(ctx, hashed_id, step_id, "run", func)

    throw(%GeneratorOpCode{
      id: hashed_id,
      display_name: step_id,
      op: "StepRun",
      data: result
    })
  end

  defp execute_step(ctx, hashed_id, step_id, step_type, func) do
    middleware = Map.get(ctx, :middleware, [])

    args = %{
      ctx: ctx,
      step_id: step_id,
      step_info: %{hashed_id: hashed_id, memoized: false, step_type: step_type}
    }

    Middleware.run_wrap_step(middleware, args, fn ->
      try do
        Middleware.run_on_step_start(middleware, args)

        result =
          Middleware.run_wrap_step_handler(middleware, args, fn ->
            func.()
          end)

        Middleware.run_on_step_complete(middleware, Map.put(args, :output, result))
        result
      rescue
        # These errors are explicit function-level controls, not ordinary step
        # body failures, so preserve the existing retry semantics.
        error in [Inngest.NonRetriableError, Inngest.RetryAfterError] ->
          Middleware.run_on_step_error(middleware, Map.put(args, :error, error))
          reraise error, __STACKTRACE__

        # Other step body exceptions are reported as StepError opcodes so the
        # executor can store the failed step result.
        error ->
          Middleware.run_on_step_error(middleware, Map.put(args, :error, error))

          throw(%GeneratorOpCode{
            id: hashed_id,
            display_name: step_id,
            op: "StepError",
            error: error_payload(error, __STACKTRACE__)
          })
      end
    end)
  end

  defp memoized_result!(ctx, hashed_id, value, opts \\ []) do
    # For targeted execution, a memoized step is only safe to replay when it is
    # the target itself or appears in the executor-provided sequential stack.
    if memoized_step_allowed?(ctx, hashed_id) do
      middleware = Map.get(ctx, :middleware, [])

      Middleware.run_wrap_step(
        middleware,
        %{ctx: ctx, step_id: hashed_id, step_info: %{hashed_id: hashed_id, memoized: true}},
        fn ->
          unwrap_memoized_result!(value, opts)
        end
      )
    else
      step_not_found!(ctx)
    end
  end

  defp transform_step_input(ctx, args) do
    ctx
    |> Map.get(:middleware, [])
    |> Middleware.run_transform_step_input(args)
  end

  defp unwrap_memoized_result!(%{"data" => value}, opts), do: decode_memoized_data!(value, opts)
  defp unwrap_memoized_result!(%{data: value}, opts), do: decode_memoized_data!(value, opts)

  # Failed memoized actions are represented as data from the executor, then
  # raised locally so normal function error handling can serialize the failure.
  defp unwrap_memoized_result!(%{"error" => error}, _opts), do: raise(Inngest.StepError, error)
  defp unwrap_memoized_result!(%{error: error}, _opts), do: raise(Inngest.StepError, error)

  defp unwrap_memoized_result!(value, _opts) do
    raise Inngest.StepError, "invalid memoized step data: #{inspect(value)}"
  end

  defp decode_memoized_data!(value, opts) do
    case Keyword.get(opts, :keys, :strings) do
      :strings -> value
      :atoms -> existing_atomize_keys!(value)
      keys -> raise Inngest.StepError, "invalid memoized step key mode: #{inspect(keys)}"
    end
  end

  defp existing_atomize_keys!(value) when is_list(value) do
    Enum.map(value, &existing_atomize_keys!/1)
  end

  defp existing_atomize_keys!(value) when is_map(value) do
    Map.new(value, fn {key, val} ->
      {existing_atom_key!(key), existing_atomize_keys!(val)}
    end)
  end

  defp existing_atomize_keys!(value), do: value

  defp existing_atom_key!(key) when is_atom(key), do: key

  defp existing_atom_key!(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError ->
      reraise Inngest.StepError.exception(
                "cannot convert memoized step key #{inspect(key)} to an existing atom"
              ),
              __STACKTRACE__
  end

  defp existing_atom_key!(key), do: key

  defp maybe_step_not_found!(ctx, hashed_id) do
    if targeted_execution?(ctx) and not targeted_step?(ctx, hashed_id) do
      step_not_found!(ctx)
    end
  end

  defp step_not_found!(ctx) do
    # StepNotFound is a generator opcode, not a function failure.
    throw(%GeneratorOpCode{
      id: Map.get(ctx, :target_step_id),
      op: "StepNotFound"
    })
  end

  defp targeted_execution?(%{target_step_id: "step"}), do: false
  defp targeted_execution?(%{target_step_id: _step_id}), do: true

  defp targeted_step?(%{target_step_id: step_id}, hashed_id), do: step_id == hashed_id

  defp memoized_step_allowed?(ctx, hashed_id) do
    cond do
      not targeted_execution?(ctx) ->
        true

      targeted_step?(ctx, hashed_id) ->
        true

      is_nil(Map.get(ctx, :stack)) ->
        true

      true ->
        hashed_id in replayable_stack(ctx)
    end
  end

  defp replayable_stack(ctx) do
    stack = Map.get(ctx, :stack) || %{}
    ids = Map.get(stack, "stack") || Map.get(stack, :stack) || []
    current = Map.get(stack, "current") || Map.get(stack, :current) || length(ids)

    # Only entries before the executor's current cursor are safe to replay.
    Enum.take(ids, current)
  end

  defp error_payload(error, stacktrace) do
    %{
      name: error.__struct__ |> Module.split() |> Enum.join("."),
      message: Exception.message(error),
      stack: Exception.format_stacktrace(stacktrace)
    }
  end
end
