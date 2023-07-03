defmodule Inngest.TestEventFn do
  @moduledoc false

  use Inngest.Function,
    name: "Awesome Event Func",
    event: "my/awesome.event"

  @counts %{
    fn_count: 0,
    step1_count: 0,
    step2_count: 0
  }

  step "step1" do
    {:ok,
     Map.merge(
       @counts,
       %{
         step: "hello world",
         fn_count: 1,
         step1_count: 1
       }
     )}
  end

  step "step2", %{data: %{fn_count: fn_count, step1_count: step1_count}} do
    {:ok,
     %{
       step: "yolo",
       fn_count: fn_count + 1,
       step1_count: step1_count,
       step2_count: 1
     }}
  end

  step "step3", %{data: %{fn_count: fn_count, step1_count: step1_count, step2_count: step2_count}} do
    {:ok,
     %{
       step: "final",
       fn_count: fn_count + 1,
       step1_count: step1_count,
       step2_count: step2_count
     }}
  end
end

defmodule Inngest.TestCronFn do
  @moduledoc false

  use Inngest.Function,
    name: "Awesome Cron Func",
    cron: "TZ=America/Los_Angeles * * * * *"
end
