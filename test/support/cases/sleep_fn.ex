defmodule Inngest.Test.Case.SleepFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "sleep-fn", name: "Sleep Function"}
  @trigger %Trigger{event: "test/plug.sleep"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    yolo = step.run(ctx, "yolo", fn -> "yolo" end)

    step.sleep(ctx, "test-sleep", "9s")

    {:ok, yolo}
  end
end
