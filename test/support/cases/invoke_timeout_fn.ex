defmodule Inngest.Test.Case.InvokeTimeoutCallerFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-timeout-caller", name: "Invoke Timeout Caller"}
  @trigger %Trigger{event: "test/invoke.timeout.caller"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _ = step.run(ctx, "step-1", fn -> %{hello: "world"} end)

    _ =
      step.invoke(ctx, "caller", %{
        function: Inngest.Test.Case.InvokedLongFn,
        data: %{yolo: true},
        timeout: "1s"
      })

    {:ok, "TIMED OUT"}
  end
end

defmodule Inngest.Test.Case.InvokedLongFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-long-target", name: "Invoked Long"}
  @trigger %Trigger{event: "test/invoked.long"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _ = step.sleep(ctx, "sleep", "5s")
    _ = step.run(ctx, "invoked", fn -> "YO!" end)

    {:ok, "INVOKED!"}
  end
end
