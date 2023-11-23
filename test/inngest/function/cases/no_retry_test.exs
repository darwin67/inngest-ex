defmodule Inngest.Function.Cases.NoRetryTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should fail without retrying" do
    event_id = send_test_event("test/plug.no-retry")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "output" => %{
                    "error" => "invalid status code: 400",
                    "message" => stacktrace,
                    "name" => "Error"
                  },
                  "run_id" => _run_id,
                  "status" => "Failed"
                }
              ]
            }} = DevServer.run_ids(event_id)

    assert stacktrace =~ "not retrying!"
  end
end
