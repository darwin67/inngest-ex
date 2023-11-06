defmodule Inngest.Test.Case.SleepUntilFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "sleep-until-fn", name: "Sleep Function"}
  @trigger %Trigger{event: "test/plug.sleep_until"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    until =
      step.run(ctx, "until", fn ->
        Timex.now()
        |> Timex.shift(seconds: 30)
        |> Timex.format!("{ISO:Extended:Z}")
      end)
      |> IO.inspect()

    step.sleep_until(ctx, "test-sleep-until", until)

    {:ok, "awake"}
  end
end
