defmodule Inngest.Test.Case.RetriableError do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger, RetryAfterError}

  @func %FnOpts{id: "retriable-fn", name: "Retriable Function", retries: 2}
  @trigger %Trigger{event: "test/plug.retriable"}

  defmodule YoloError do
    defexception message: "YOLO!!!"
  end

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _success = step.run(ctx, "should-work", fn -> "foobar" end)

    _retry =
      step.run(ctx, "should-retry", fn ->
        raise RetryAfterError, message: "YOLO!!!", seconds: 5
      end)

    _ = step.run(ctx, "wont-run", fn -> "hello" end)

    {:ok, "completed"}
  end

  def handle_failure(ctx, %{step: step} = _args) do
    _ =
      step.run(ctx, "handle-failure", fn ->
        "CATCH ERROR!!!"
      end)

    {:ok, "error handled"}
  end
end
