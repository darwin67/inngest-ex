defmodule Inngest.Function.Cases.InvokeTimeoutTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 5_000

  @tag :integration
  test "should fail with timeout error" do
    event_id = send_test_event("test/invoke.timeout.caller")
    Process.sleep(@default_sleep)

    assert {
             :ok,
             %{
               "data" => [
                 %{
                   "output" => %{
                     "name" => error,
                     "message" => message,
                     "stack" => _
                   },
                   "run_id" => _,
                   "status" => "Failed"
                 }
               ]
             }
           } = DevServer.run_ids(event_id)

    assert error == "Elixir.Inngest.NonRetriableError"

    assert message ==
             "InngestInvokeTimeoutError: Timed out waiting for invoked function to complete"
  end
end
