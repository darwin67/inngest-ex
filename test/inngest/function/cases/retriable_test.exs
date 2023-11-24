defmodule Inngest.Function.Cases.RetriableTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @sec 1_000

  @tag :integration
  test "should fail after retrying" do
    event_id = send_test_event("test/plug.retriable")
    Process.sleep(5 * @sec)

    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => _run_id,
                  "status" => "Running"
                }
              ]
            }} = DevServer.run_ids(event_id)

    Process.sleep(10 * @sec)

    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => _run_id,
                  "status" => "Running"
                }
              ]
            }} = DevServer.run_ids(event_id)

    Process.sleep(20 * @sec)

    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => _run_id,
                  "output" => %{
                    "error" => "invalid status code: 500",
                    "message" => stacktrace
                  },
                  "status" => "Failed"
                }
              ]
            }} = DevServer.run_ids(event_id)

    assert stacktrace =~ "YOLO!!!"
  end
end
