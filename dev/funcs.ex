defmodule Inngest.Dev.EventFn do
  use Inngest.Function,
    name: "test func",
    event: "test/event"

  step "test 1st step" do
    {:ok, %{hello: "world"}}
  end

  step "test 2nd step" do
    {:ok, %{yo: "lo"}}
  end

  step "test 3rd - state accumulate" do
    {:ok, %{result: "ok"}}
  end
end

defmodule Inngest.Dev.CronFn do
  use Inngest.Function,
    name: "test cron",
    cron: "TZ=America/Los_Angeles * * * * *"
end
