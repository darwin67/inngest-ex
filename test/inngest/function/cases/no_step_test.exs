defmodule Inngest.Function.Cases.NoStepTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should run successfully" do
    event_id = send_test_event("test/plug.no-step")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "output" => "hello world",
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(event_id)
  end
end
