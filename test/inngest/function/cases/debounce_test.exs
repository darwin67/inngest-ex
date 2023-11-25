defmodule Inngest.Function.Cases.DebounceTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 3_000

  @tag :integration
  test "should run successfully" do
    event_id = send_test_event("test/plug.debounce")
    Process.sleep(@default_sleep)

    assert {:ok, %{"data" => []}} = DevServer.run_ids(event_id)

    next_id = send_test_event("test/plug.debounce")
    Process.sleep(@default_sleep)

    # check that there are still no function runs trigger by 'event_id'
    assert {:ok, %{"data" => []}} = DevServer.run_ids(event_id)
    assert {:ok, %{"data" => []}} = DevServer.run_ids(next_id)

    Process.sleep(@default_sleep * 2)

    assert {:ok,
            %{
              "data" => [
                %{
                  "output" => "debounced",
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(next_id)
  end

  describe "with key" do
    @event_name "test/plug.debounce-with-key"

    @tag :integration
    test "should only debounce when key matches" do
      hello = send_test_event(@event_name, %{foobar: "hello"})
      yolo = send_test_event(@event_name, %{foobar: "yolo"})
      Process.sleep(@default_sleep)

      # have not started yet
      assert {:ok, %{"data" => []}} = DevServer.run_ids(hello)
      assert {:ok, %{"data" => []}} = DevServer.run_ids(yolo)
      # send again
      yolo_2 = send_test_event(@event_name, %{foobar: "yolo"})

      Process.sleep(@default_sleep)

      assert {:ok, %{"data" => []}} = DevServer.run_ids(yolo_2)

      Process.sleep(@default_sleep * 2)
      assert {:ok, %{"data" => []}} = DevServer.run_ids(yolo)

      assert {:ok,
              %{
                "data" => [
                  %{
                    "output" => "debounced",
                    "status" => "Completed"
                  }
                ]
              }} = DevServer.run_ids(hello)

      assert {:ok,
              %{
                "data" => [
                  %{
                    "output" => "debounced",
                    "status" => "Completed"
                  }
                ]
              }} = DevServer.run_ids(yolo_2)
    end
  end
end
