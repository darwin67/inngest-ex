defmodule Inngest.StepTool do
  @moduledoc false

  alias Inngest.Event
  alias Inngest.Function.{Context, UnhashedOp, GeneratorOpCode}

  @type id() :: binary()
  @type datetime() :: binary() | DateTime.t() | Date.t() | NaiveDateTime.t()

  @spec run(Context.t(), id(), fun()) :: any()
  def run(%{steps: steps} = ctx, step_id, func) do
    op = UnhashedOp.new(ctx, "Step", step_id)
    hashed_id = UnhashedOp.hash(op)

    case Map.get(steps, hashed_id) do
      nil -> report_run_step(ctx, hashed_id, step_id, func)
      val -> memoized_result!(ctx, hashed_id, val)
    end
  end

  @spec sleep(Context.t(), id(), binary()) :: nil
  def sleep(%{steps: steps} = ctx, step_id, duration) do
    op = UnhashedOp.new(ctx, "Sleep", step_id)
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
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

        # if not, execute function
        # TODO: handle error responses as well
        {:ok, %{"ids" => event_ids, "status" => 200}} = Inngest.Client.send(events)

        # cancel execution and return with opcode
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

  defp report_run_step(ctx, hashed_id, step_id, func) do
    cond do
      targeted_step?(ctx, hashed_id) ->
        execute_run_step(hashed_id, step_id, func)

      targeted_execution?(ctx) ->
        step_not_found!(ctx)

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

  defp execute_run_step(hashed_id, step_id, func) do
    result = func.()

    throw(%GeneratorOpCode{
      id: hashed_id,
      display_name: step_id,
      op: "StepRun",
      data: result
    })
  rescue
    error ->
      throw(%GeneratorOpCode{
        id: hashed_id,
        display_name: step_id,
        op: "StepError",
        error: error_payload(error, __STACKTRACE__)
      })
  end

  defp memoized_result!(ctx, hashed_id, value) do
    if memoized_step_allowed?(ctx, hashed_id) do
      unwrap_memoized_result!(value)
    else
      step_not_found!(ctx)
    end
  end

  defp unwrap_memoized_result!(%{"data" => value}), do: value
  defp unwrap_memoized_result!(%{data: value}), do: value

  defp unwrap_memoized_result!(%{"error" => error}), do: raise(Inngest.StepError, error)
  defp unwrap_memoized_result!(%{error: error}), do: raise(Inngest.StepError, error)

  defp unwrap_memoized_result!(value) do
    raise Inngest.StepError, "invalid memoized step data: #{inspect(value)}"
  end

  defp maybe_step_not_found!(ctx, hashed_id) do
    if targeted_execution?(ctx) and not targeted_step?(ctx, hashed_id) do
      step_not_found!(ctx)
    end
  end

  defp step_not_found!(ctx) do
    throw(%GeneratorOpCode{
      id: Map.get(ctx, :target_step_id),
      op: "StepNotFound"
    })
  end

  defp targeted_execution?(%{target_step_id: step_id}), do: step_id not in [nil, "step"]
  defp targeted_execution?(_ctx), do: false

  defp targeted_step?(%{target_step_id: step_id}, hashed_id), do: step_id == hashed_id
  defp targeted_step?(_ctx, _hashed_id), do: false

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
