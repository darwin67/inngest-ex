defmodule Inngest.Test.Case.StepFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "step-fn", name: "Step Function"}
  @trigger %Trigger{event: "test/plug.step"}

  @count 0

  @impl true
  def exec(ctx, %{step: step} = _args) do
    step1 = step.run(ctx, "step1", fn -> @count + 1 end)
    tmp = step1 + 1
    step2 = step.run(ctx, "step2", fn -> tmp + 1 end)
    tmp2 = step2 + 1

    {:ok, tmp2 + 1}
  end
end
