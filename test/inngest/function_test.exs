defmodule Inngest.FunctionTest do
  use ExUnit.Case, async: true

  alias Inngest.Function.Trigger

  defmodule TestEventFunction do
    use Inngest.Function, name: "Awesome Event Func", event: "my/awesome.event"
  end

  defmodule TestCronFunction do
    use Inngest.Function, name: "Awesome Cron Func", cron: "America/Los_Angeles * * * * *"
  end

  describe "slug/0" do
    test "return name of function as slug" do
      assert "awesome-event-func" == TestEventFunction.slug()
    end
  end

  describe "name/0" do
    test "return name of function" do
      assert "Awesome Event Func" == TestEventFunction.name()
    end
  end

  describe "trigger/0" do
    test "return an event trigger for event functions" do
      assert %Trigger{event: "my/awesome.event"} == TestEventFunction.trigger()
    end

    test "return a cron trigger for cron functions" do
      assert %Trigger{cron: "America/Los_Angeles * * * * *"} == TestCronFunction.trigger()
    end
  end

  describe "serve/0" do
    test "event function should return approprivate map" do
      assert %{
               id: "awesome-event-func",
               name: "Awesome Event Func",
               triggers: [
                 %Trigger{event: "my/awesome.event"}
               ],
               steps: %{
                 "dummy-step" => %{
                   id: _,
                   name: _,
                   runtime: %{
                     type: "http",
                     url: _
                   },
                   retries: %{
                     attempts: _
                   }
                 }
               }
             } = TestEventFunction.serve()
    end

    test "cron function should return appropriate map" do
      assert %{
               id: "awesome-cron-func",
               name: "Awesome Cron Func",
               triggers: [
                 %Trigger{cron: "America/Los_Angeles * * * * *"}
               ]
             } = TestCronFunction.serve()
    end
  end
end
