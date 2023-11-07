defmodule Inngest.StepTool do
  @moduledoc false

  alias Inngest.Event
  alias Inngest.Function.{Context, UnhashedOp, GeneratorOpCode}

  @type id() :: binary()
  @type datetime() :: binary() | DateTime.t() | Date.t() | NaiveDateTime.t()

  @spec run(Context.t(), id(), fun()) :: any()
  def run(%{steps: steps} = _ctx, step_id, func) do
    op = %UnhashedOp{name: step_id, op: "Step"}
    hashed_id = UnhashedOp.hash(op)

    # check for hash
    case Map.get(steps, hashed_id) do
      nil ->
        # if not, execute function
        result = func.()

        # cancel execution and return with opcode
        throw(%GeneratorOpCode{
          id: hashed_id,
          name: step_id,
          display_name: step_id,
          op: op.op,
          data: result
        })

      # if found, return value
      val ->
        val
    end
  end

  @spec sleep(Context.t(), id(), binary()) :: nil
  def sleep(%{steps: steps} = _ctx, step_id, duration) do
    op = %UnhashedOp{name: step_id, op: "Sleep"}
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
      throw(%GeneratorOpCode{
        id: hashed_id,
        name: duration,
        display_name: step_id,
        op: op.op,
        data: nil
      })
    end
  end

  @spec sleep_until(Context.t(), id(), datetime()) :: nil
  def sleep_until(%{steps: steps} = _ctx, step_id, time) do
    op = %UnhashedOp{name: step_id, op: "Sleep"}
    hashed_id = UnhashedOp.hash(op)

    if Map.has_key?(steps, hashed_id) do
      nil
    else
      case Inngest.Function.validate_datetime(time) do
        {:ok, datetime} ->
          throw(%GeneratorOpCode{
            id: hashed_id,
            name: datetime,
            display_name: datetime,
            op: op.op
          })

        {:error, error} ->
          {:error, error}
      end
    end
  end

  @spec wait_for_event(Context.t(), id(), map()) :: map()
  def wait_for_event(%{steps: steps} = _ctx, step_id, opts) do
    op = %UnhashedOp{name: step_id, op: "WaitForEvent"}
    hashed_id = UnhashedOp.hash(op)

    if steps |> Map.has_key?(hashed_id) do
      case steps |> Map.get(hashed_id) do
        nil -> nil
        event -> Event.from(event)
      end
    else
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

  def send_event(%{steps: steps} = _ctx, step_id, events) do
    op = %UnhashedOp{name: step_id, op: "Step"}
    hashed_id = UnhashedOp.hash(op)

    case Map.get(steps, hashed_id) do
      nil ->
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
          op: op.op,
          data: %{event_ids: event_ids}
        })

      # if found, return value
      val ->
        val
    end
  end
end
