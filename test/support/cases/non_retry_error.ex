defmodule Inngest.Test.Case.NonRetriableError do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "non-retry-fn", name: "Non Retriable Function"}
  @trigger %Trigger{event: "test/plug.no-retry"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _success = step.run(ctx, "should-work", fn -> "foobar" end)

    _fail =
      step.run(ctx, "should-fail", fn ->
        raise Inngest.NonRetriableError, message: "not retrying!"
      end)

    _ = step.run(ctx, "should-not-run", fn -> "yolo" end)

    {:ok, "completed"}
  end
end
