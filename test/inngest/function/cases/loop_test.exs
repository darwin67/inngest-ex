defmodule Inngest.Function.Cases.LoopTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should calculate sum correctly" do
    event_id = send_test_event("test/plug.loop")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "run_id" => _run_id,
                  "output" => 30,
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(event_id)
  end
end
