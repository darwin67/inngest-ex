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
end
