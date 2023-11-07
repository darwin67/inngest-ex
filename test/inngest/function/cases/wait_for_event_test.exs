defmodule Inngest.Function.Cases.WaitForEventTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should have access to event when fulfilled" do
    event_id = send_test_event("test/plug.wait-for-event")
    Process.sleep(@default_sleep)

    # it should be waiting
    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => run_id,
                  "status" => "Running",
                  "ended_at" => nil
                }
              ]
            }} = DevServer.run_ids(event_id)

    # send the waited event to continue
    assert _ = send_test_event("test/yolo.wait")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => %{
                "event_id" => ^event_id,
                "run_id" => ^run_id,
                "output" => "fulfilled",
                "status" => "Completed"
              }
            }} = DevServer.fn_run(run_id)
  end

  @tag :integration
  test "should get nil when not fulfilled" do
    event_id = send_test_event("test/plug.wait-for-event")
    Process.sleep(@default_sleep)

    # it should be waiting
    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => run_id,
                  "status" => "Running",
                  "ended_at" => nil
                }
              ]
            }} = DevServer.run_ids(event_id)

    # Don't do anything
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => %{
                "event_id" => ^event_id,
                "run_id" => ^run_id,
                "output" => "empty",
                "status" => "Completed"
              }
            }} = DevServer.fn_run(run_id)
  end
end
