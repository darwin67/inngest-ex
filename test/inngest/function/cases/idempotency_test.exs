defmodule Inngest.Function.Cases.IdempotencyTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 3_000

  @tag :integration
  test "should only run 1 out of 10" do
    event_ids =
      Enum.map(1..10, fn _ -> send_test_event("test/plug.idempotency", %{foobar: false}) end)

    Process.sleep(@default_sleep)

    fn_runs =
      event_ids
      |> Enum.map(fn id ->
        {:ok, %{"data" => data}} = DevServer.run_ids(id)

        if Enum.count(data) == 1 do
          assert [
                   %{
                     "output" => "Done",
                     "status" => "Completed",
                     "run_id" => run_id
                   }
                 ] = data

          run_id
        else
          nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    assert Enum.count(fn_runs) == 1

    # sending with a different value will run
    other = send_test_event("test/plug.idempotency", %{foobar: "hello"})
    Process.sleep(@default_sleep)

    assert {:ok,
            %{
              "data" => [
                %{
                  "output" => "Done",
                  "status" => "Completed"
                }
              ]
            }} = DevServer.run_ids(other)
  end
end
