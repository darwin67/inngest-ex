defmodule Inngest.TestEventFn do
  @moduledoc false

  use Inngest.Function,
    name: "Awesome Event Func",
    event: "my/awesome.event"

  @impl true
  def perform(_args) do
    fn_count = 0
    step1_count = 0
    step2_count = 0

    step1 =
      Step.run(%{}, "step #1", fn ->
        %{step1: "hello world", fn_count: fn_count + 1, step1_count: step1_count + 1}
      end)

    step2 =
      Step.run(%{}, "step #2", fn ->
        %{fn_count: fn_count} = step1

        %{step1: "hello world", fn_count: fn_count + 1, step2_count: step2_count + 1}
      end)

    result =
      %{success: true}
      |> Map.merge(step1)
      |> Map.merge(step2)

    {:ok, result}
  end
end

defmodule Inngest.TestCronFn do
  @moduledoc false

  use Inngest.Function,
    name: "Awesome Cron Func",
    cron: "TZ=America/Los_Angeles * * * * *"

  @impl true
  def perform(_args), do: {:ok, %{success: true}}
end
