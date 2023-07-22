defmodule Inngest.Router.HelperTest do
  use ExUnit.Case, async: true

  alias Inngest.Router.Helper

  describe "func_map/2" do
    test "should return a function map" do
      path = "/api/inngest"
      funcs = [Inngest.TestEventFn]

      assert %{
               "awesome-event-func" => %{
                 id: "awesome-event-func",
                 mod: Inngest.TestEventFn,
                 steps: %{
                   step: %Inngest.Function.Step{
                     id: :step,
                     name: "step"
                   }
                 },
                 triggers: [
                   %Inngest.Function.Trigger{
                     event: "my/awesome.event",
                     expression: nil,
                     cron: nil
                   }
                 ]
               }
             } = Helper.func_map(path, funcs)
    end
  end
end
