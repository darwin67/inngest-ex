defmodule Inngest.StepTool do
  @moduledoc false

  alias Inngest.Event
  alias Inngest.Function.{Context, UnhashedOp, GeneratorOpCode}

  @type id() :: binary()
  @type datetime() :: binary() | DateTime.t() | Date.t() | NaiveDateTime.t()
  @type run_opt() :: {:keys, :strings | :atoms}

  @spec run(Context.t(), id(), fun()) :: any()
  def run(ctx, step_id, func), do: run(ctx, step_id, func, [])

  @spec run(Context.t(), id(), fun(), [run_opt()]) :: any()
  def run(%{steps: steps} = ctx, step_id, func, opts) do
    op = UnhashedOp.new(ctx, "Step", step_id)
    hashed_id = UnhashedOp.hash(op)

    # Memoized steps must return without reporting another opcode. New steps
    # either execute immediately, plan, or produce StepNotFound for targets.
    case Map.get(steps, hashed_id) do
      nil -> report_run_step(ctx, hashed_id, step_id, func)
      val -> memoized_result!(ctx, hashed_id, val, opts)
    end
  end

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
              function_id: func.slug(),
              payload: %{data: data, v: v},
              timeout: timeout
            }
          else
            %{
              function_id: func.slug(),
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

  def send_event(%{steps: steps} = ctx, step_id, events) do
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

        # TODO: handle error responses as well
        {:ok, %{"ids" => event_ids, "status" => 200}} = Inngest.Client.send(events)

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

  @spec report_run_step(Context.t(), binary(), binary(), fun()) :: no_return()
  defp report_run_step(ctx, hashed_id, step_id, func) do
    cond do
      # The executor can ask for one specific hashed step ID. Only that step is
      # allowed to execute in this traversal.
      targeted_step?(ctx, hashed_id) ->
        execute_run_step(hashed_id, step_id, func)

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
        execute_run_step(hashed_id, step_id, func)
    end
  end

  @spec execute_run_step(binary(), binary(), fun()) :: no_return()
  defp execute_run_step(hashed_id, step_id, func) do
    result = func.()

    throw(%GeneratorOpCode{
      id: hashed_id,
      display_name: step_id,
      op: "StepRun",
      data: result
    })
  rescue
    # These errors are explicit function-level controls, not ordinary step body
    # failures, so preserve the existing retry semantics.
    error in [Inngest.NonRetriableError, Inngest.RetryAfterError] ->
      reraise error, __STACKTRACE__

    # Other step body exceptions are reported as StepError opcodes so the
    # executor can store the failed step result.
    error ->
      throw(%GeneratorOpCode{
        id: hashed_id,
        display_name: step_id,
        op: "StepError",
        error: error_payload(error, __STACKTRACE__)
      })
  end

  defp memoized_result!(ctx, hashed_id, value, opts \\ []) do
    # For targeted execution, a memoized step is only safe to replay when it is
    # the target itself or appears in the executor-provided sequential stack.
    if memoized_step_allowed?(ctx, hashed_id) do
      unwrap_memoized_result!(value, opts)
    else
      step_not_found!(ctx)
    end
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
