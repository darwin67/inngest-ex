defmodule Inngest.Test.Case.ConcurrencyFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{
    id: "concurrency-fn",
    name: "Concurrency Function",
    concurrency: %{
      limit: 2
    }
  }
  @trigger %Trigger{event: "test/plug.throttle"}

  @impl true
  @spec exec(any, %{:step => atom, optional(any) => any}) :: {:ok, <<_::72>>}
  def exec(ctx, %{step: step} = _args) do
    _ =
      step.run(ctx, "wait", fn ->
        Process.sleep(3_000)
        "waited"
      end)

    {:ok, "Throttled"}
  end
end
