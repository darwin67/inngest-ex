defmodule Inngest.Dev.EventFn do
  use Inngest.Function,
    name: "test func",
    event: "test/event"

  step "test 1st step" do
    %{hello: "world"}
  end

  step "test 2nd step" do
    %{yo: "lo"}
  end

  @impl true
  def perform(_) do
    # val =
    #   Step.run(_, "test 1st step", fn ->
    #     %{hello: "World"}
    #   end)

    val = %{final: "success"}

    {:ok, val}
  end
end

defmodule Inngest.Dev.CronFn do
  use Inngest.Function,
    name: "test cron",
    cron: "TZ=America/Los_Angeles * * * * *"

  @impl true
  def perform(_), do: {:ok, %{hello: "cron"}}
end
