defmodule Inngest.Test.Case.WaitForEventFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "wait-for-event-fn", name: "Wait for Event Function"}
  @trigger %Trigger{event: "test/plug.wait-for-event"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    evt =
      step.wait_for_event(ctx, "wait-test", %{
        event: "test/yolo.wait",
        timeout: "8s"
      })

    result = if is_nil(evt), do: "empty", else: "fulfilled"

    {:ok, result}
  end
end
