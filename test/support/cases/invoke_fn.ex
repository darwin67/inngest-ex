defmodule Inngest.Test.Case.InvokeCallerFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-caller", name: "Invoke Caller"}
  @trigger %Trigger{event: "test/invoke.caller"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _ = step.run(ctx, "step-1", fn -> %{hello: "world"} end)

    res =
      step.invoke(ctx, "caller", %{
        function: Inngest.Test.Case.InvokedFn,
        data: %{yolo: true},
        timeout: "5m"
      })

    {:ok, res}
  end
end

defmodule Inngest.Test.Case.InvokedFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-target", name: "Invoked"}
  @trigger %Trigger{event: "test/invoked"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _ = step.run(ctx, "invoked", fn -> "YO!" end)

    {:ok, "INVOKED!"}
  end
end
