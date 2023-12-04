defmodule Inngest.Test.Case.LoopFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "loop-fn", name: "Loop Function"}
  @trigger %Trigger{event: "test/plug.loop"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    sum =
      Enum.map(1..5, fn n ->
        step.run(ctx, "multi", fn -> n * 2 end)
      end)
      |> Enum.sum()

    {:ok, sum}
  end
end
