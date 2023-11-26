defmodule Inngest.Test.Case.BatchFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{
    id: "batch-fn",
    name: "Batch Function",
    batch_events: %{
      max_size: 5,
      timeout: "5s"
    }
  }
  @trigger %Trigger{event: "test/plug.batching"}

  @impl true
  def exec(ctx, %{events: events, step: step} = _args) do
    _ = step.run(ctx, "batch", fn -> ":+1" end)
    count = Enum.count(events)

    {:ok, "Batched: #{count}"}
  end
end
