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
end

defmodule Inngest.Dev.CronFn do
  use Inngest.Function,
    name: "test cron",
    cron: "TZ=America/Los_Angeles * * * * *"
end
