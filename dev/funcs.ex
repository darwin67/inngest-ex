defmodule Inngest.Dev.EventFn do
  use Inngest.Function,
    name: "test func",
    event: "test/event"

  run "test 1st run" do
    {:ok, %{run: "do something"}}
  end

  step "test 1st step" do
    {:ok, %{hello: "world"}}
  end

  sleep "2s"

  step "test 2nd step" do
    {:ok, %{yo: "lo"}}
  end

  sleep "2s"
  # sleep_until "2023-07-12T07:19:00Z"

  step "test 3rd - state accumulate" do
    {:ok, %{result: "ok"}}
  end

  wait_for_event "test/wait", timeout: "1d" do
    {:ok, %{wait: "event"}}
  end

  run "result", %{data: data} do
    {:ok, data}
  end
end

defmodule Inngest.Dev.CronFn do
  use Inngest.Function,
    name: "test cron",
    cron: "TZ=America/Los_Angeles * * * * *"
end
