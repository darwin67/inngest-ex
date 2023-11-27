defmodule Inngest.Test.Case.CancelOnFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{
    id: "cancelon-fn",
    name: "CancelOn Function",
    cancel_on: %{
      event: "test/cancel"
    }
  }
  @trigger %Trigger{event: "test/plug.cancel"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    step.sleep(ctx, "wait", "10s")

    {:ok, "Not cancelled!!"}
  end
end
