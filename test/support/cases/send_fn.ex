defmodule Inngest.Test.Case.SendFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "send-fn", name: "Send Function"}
  @trigger %Trigger{event: "test/plug.send"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    step.send_event(ctx, "send-test", %{
      name: "test/yolo",
      data: %{}
    })
    |> IO.inspect()

    {:ok, "sent"}
  end
end
