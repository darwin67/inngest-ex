defmodule Inngest.EventTest do
  use ExUnit.Case, async: true

  alias Inngest.Event

  describe "from/1" do
    @data %{
      name: "test/hello",
      data: %{"foo" => "bar"},
      ts: 1_701_317_479_000
    }

    test "construct an Event object from a map" do
      assert %Event{
               id: "",
               name: "test/hello",
               data: %{"foo" => "bar"},
               ts: 1_701_317_479_000,
               datetime: ~U[2023-11-30 04:11:19.000Z],
               v: nil
             } = Event.from(@data)
    end

    test "return an empty event if data is not map" do
      assert %Event{
               id: "",
               name: nil,
               data: nil,
               ts: nil,
               datetime: nil,
               v: nil
             } = Event.from(10)
    end
  end
end
