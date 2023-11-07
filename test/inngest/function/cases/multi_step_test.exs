defmodule Inngest.Function.Cases.MultiStepTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should run successfully" do
    event_id = send_test_event("test/plug.step")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "output" => 5,
                  "run_id" => _run_id,
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(event_id)

    # TODO: check on step outputs
    # assert {:ok, resp} = DevServer.fn_run(run_id) |> IO.inspect()
  end
end
