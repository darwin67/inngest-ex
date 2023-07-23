defmodule Inngest.Dev.CronFn do
  use Inngest.Function,
    name: "test cron",
    cron: "TZ=America/Los_Angeles * * * * *"

  step "show current time" do
    {:ok, %{time: Timex.now()}}
  end
end
