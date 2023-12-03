defmodule Inngest.TestEventFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "test-event", name: "App / Email: Awesome Event Func"}
  @trigger %Trigger{event: "my/awesome.event"}

  # @counts %{
  #   fn_count: 0,
  #   step1_count: 0,
  #   step2_count: 0
  # }

  @impl true
  def exec(_ctx, _args) do
    {:ok, "hello world"}
  end

  # run "exec1" do
  #   {:ok, %{run: "something"}}
  # end

  # step "step1", %{data: data} do
  #   result =
  #     @counts
  #     |> Map.merge(data)
  #     |> Map.merge(%{
  #       step: "hello world",
  #       fn_count: 1,
  #       step1_count: 1
  #     })

  #   {:ok, result}
  # end

  # sleep("2s")

  # step "step2", %{data: %{fn_count: fn_count, step1_count: step1_count}} do
  #   {:ok,
  #    %{
  #      step: "yolo",
  #      fn_count: fn_count + 1,
  #      step1_count: step1_count,
  #      step2_count: 1
  #    }}
  # end

  # sleep("3s")

  # run "exec2" do
  #   {:ok, %{run: "again"}}
  # end

  # sleep "until some date" do
  #   "2023-07-12T06:35:00Z"
  # end

  # step "step3", %{
  #   data: %{fn_count: fn_count, step1_count: step1_count, step2_count: step2_count, run: run}
  # } do
  #   {:ok,
  #    %{
  #      step: "final",
  #      fn_count: fn_count + 1,
  #      step1_count: step1_count,
  #      step2_count: step2_count,
  #      run: run
  #    }}
  # end

  # step "step4" do
  #   {:ok, "foobar"}
  # end

  # step "step5" do
  #   :ok
  # end

  # run "final", %{data: %{fn_count: fn_count}} do
  #   {:ok,
  #    %{
  #      fn_count: fn_count + 1,
  #      yo: "lo"
  #    }}
  # end
end

defmodule Inngest.TestCronFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "test-cron", name: "Awesome Cron Func"}
  @trigger %Trigger{cron: "TZ=America/Los_Angeles * * * * *"}

  @impl true
  def exec(_ctx, _args) do
    {:ok, "cron"}
  end
end
