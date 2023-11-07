defmodule Inngest.Function.Cases.SendEventTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should run successfully" do
    event_id = send_test_event("test/plug.send")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "output" => %{
                    "event_ids" => event_ids
                  },
                  "run_id" => _run_id,
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(event_id)

    assert Enum.count(event_ids) > 0
    assert is_list(event_ids)
  end
end
