defmodule Inngest.Test.EventFn do
  use Inngest.Function,
    name: "Awesome Event Func",
    event: "my/awesome.event"

  @impl true
  def perform(_args), do: {:ok, %{success: true}}
end

defmodule Inngest.Test.CronFn do
  use Inngest.Function,
    name: "Awesome Cron Func",
    cron: "America/Los_Angeles * * * * *"

  @impl true
  def perform(_args), do: {:ok, %{success: true}}
end
