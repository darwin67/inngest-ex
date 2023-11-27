defmodule Inngest.Function.Cases.CancelOnTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :skip
  @tag :integration
  test "should cancel the running function successfully" do
    event_id = send_test_event("test/plug.cancel")

    Process.sleep(@default_sleep)

    # still running
    assert {:ok,
            %{
              "data" => [
                %{"status" => "Running"}
              ]
            }} = DevServer.run_ids(event_id)

    _cancel = send_test_event("test/cancel")
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                # bug - INN-2384
                %{"status" => "Cancelled"}
              ]
            }} = DevServer.run_ids(event_id)
  end
end
