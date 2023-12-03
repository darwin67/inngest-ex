defmodule Inngest.Test.Case.SleepUntilFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "sleep-until-fn", name: "Sleep Function"}
  @trigger %Trigger{event: "test/plug.sleep_until"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    until =
      step.run(ctx, "until", fn ->
        Timex.now()
        |> Timex.shift(seconds: 9)
        |> Timex.format!("{YYYY}-{0M}-{0D}T{h24}:{m}:{s}Z")
      end)

    step.sleep_until(ctx, "test-sleep-until", until)

    {:ok, "awake"}
  end
end
