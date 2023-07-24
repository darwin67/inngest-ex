defmodule Inngest.Dev.EventFn do
  @moduledoc false

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
  # sleep "until 1m later" do
  #   "2023-07-18T07:31:00Z"
  # end

  step "test 3rd - state accumulate" do
    {:ok, %{result: "ok"}}
  end

  # wait_for_event "test/wait" do
  #   match = "data.yo"
  #   [timeout: "1d", if: "event.#{match} == async.#{match}"]
  # end

  # wait_for_event "test/wait", do: [timeout: "1d", match: "data.yo"]

  run "result", %{data: data} do
    {:ok, data}
  end
end
