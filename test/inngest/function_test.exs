defmodule Inngest.FunctionTest do
  use ExUnit.Case, async: true

  alias Inngest.Function
  alias Inngest.Trigger
  alias Inngest.{TestEventFn, TestCronFn}

  describe "slug/0" do
    test "return name of function as slug" do
      assert "inngestapp-test-event" == TestEventFn.slug()
    end
  end

  describe "name/0" do
    test "return name of function" do
      assert "App / Email: Awesome Event Func" == TestEventFn.name()
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

  describe "serve/1" do
    test "event function should return approprivate map" do
      assert [
               %{
                 id: "inngestapp-test-event",
                 name: "App / Email: Awesome Event Func",
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
               }
             ] = TestEventFn.serve("/api/inngest")
    end

    test "cron function should return appropriate map" do
      assert [
               %{
                 id: "inngestapp-test-cron",
                 name: "Awesome Cron Func",
                 triggers: [
                   %Trigger{cron: "TZ=America/Los_Angeles * * * * *"}
                 ]
               }
             ] = TestCronFn.serve("/api/inngest")
    end
  end

  describe "validate_datetime/1" do
    @formats [
      # RFC3339
      "2013-03-05T23:25:19+02:00",
      # RFC3339z
      "2013-03-05T23:25:19Z",
      # RFC1123
      "Tue, 05 Mar 2013 23:25:19 +0200",
      # RFC822
      "Mon, 05 Jun 14 23:20:59 UT",
      # RFC822z
      "Mon, 05 Jun 14 23:20:59 Z",
      # Custom
      "Monday, 02-Jan-06 15:04:05 MST",
      "Mon Jan 02 15:04:05 -0700 2006",
      # UNIX
      "Mon Jan 2 15:04:05 MST 2006",
      # ANSIC
      "Tue Mar 5 23:25:19 2013",
      # Timestamp, second & millisecond
      "Jan 2 15:04:05",
      "Jan 2 15:04:05.000",
      # ISOdate
      "2006-01-02"
    ]

    for fmt <- @formats do
      test "should be able to parse '#{fmt}'" do
        datetime = unquote(fmt)
        assert _ = Function.validate_datetime(datetime)
      end
    end

    test "should accept Datetime objects" do
      dt = DateTime.new!(~D[2024-05-24], ~T[13:26:08.003], "Etc/UTC")
      expected = "2024-05-24T13:26:08Z"
      assert {:ok, ^expected} = Function.validate_datetime(dt)
    end

    test "should return error for invalid string format" do
      assert {:error, "Unknown format for DateTime"} = Function.validate_datetime("yolo")
    end

    test "should return error with invalid input type" do
      assert {:error, "Expect valid DateTime formatted input"} = Function.validate_datetime(10)
    end
  end
end
