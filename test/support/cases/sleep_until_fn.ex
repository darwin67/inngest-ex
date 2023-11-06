defmodule Inngest.Test.Case.SleepFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "sleep-until-fn", name: "Sleep Function"}
  @trigger %Trigger{event: "test/plug.sleep_until"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    now = step.run(ctx, "now", fn -> Timex.now() end)
    until = Timex.shift(now, seconds: 10)

    step.sleep_until(ctx, "test-sleep-until", until)

    {:ok, "awake"}
  end
end
