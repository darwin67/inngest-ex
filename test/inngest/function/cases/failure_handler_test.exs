defmodule Inngest.Function.Cases.RetriableTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 20_000
  @event_name "test/plug.retriable"

  @tag :integration
  test "should fail after retrying and failure is handled" do
    event_id = send_test_event(@event_name)
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => _run_id,
                  "output" => %{
                    "message" => message,
                    "name" => "Elixir.Inngest.RetryAfterError",
                    "stack" => _
                  },
                  "status" => "Failed"
                }
              ]
            }} = DevServer.run_ids(event_id)

    assert message == "YOLO!!!"

    {:ok, %{"data" => events}} = DevServer.list_events()

    assert %{"internal_id" => failed_id} =
             events
             |> Enum.find(fn evt ->
               Map.get(evt, "name") == "inngest/function.failed" &&
                 get_in(evt, ["data", "event", "name"]) == @event_name
             end)

    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => _,
                  "output" => "error handled",
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(failed_id)
  end
end
