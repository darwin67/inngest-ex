defmodule Inngest.FunctionTest do
  use ExUnit.Case, async: true

  alias Inngest.Function.Trigger
  alias Inngest.{TestEventFn, TestCronFn}

  describe "slug/0" do
    test "return name of function as slug" do
      assert "awesome-event-func" == TestEventFn.slug()
    end
  end

  describe "name/0" do
    test "return name of function" do
      assert "Awesome Event Func" == TestEventFn.name()
    end
  end

  describe "trigger/0" do
    test "return an event trigger for event functions" do
      assert %Trigger{event: "my/awesome.event"} == TestEventFn.trigger()
    end

    test "return a cron trigger for cron functions" do
      assert %Trigger{cron: "TZ=America/Los_Angeles * * * * *"} == TestCronFn.trigger()
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
                 step: %{
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
             } = TestEventFn.serve()
    end

    test "cron function should return appropriate map" do
      assert %{
               id: "awesome-cron-func",
               name: "Awesome Cron Func",
               triggers: [
                 %Trigger{cron: "TZ=America/Los_Angeles * * * * *"}
               ]
             } = TestCronFn.serve()
    end
  end
end
