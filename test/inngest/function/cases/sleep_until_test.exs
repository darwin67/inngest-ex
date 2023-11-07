defmodule Inngest.Function.Cases.SleepUntilTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should run successfully" do
    event_id = send_test_event("test/plug.sleep_until")
    Process.sleep(@default_sleep)

    # it should be sleeping so have not completed
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

    # wait till sleep is done
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => %{
                "event_id" => ^event_id,
                "run_id" => ^run_id,
                "output" => "awake",
                "status" => "Completed"
              }
            }} = DevServer.fn_run(run_id)
  end
end
