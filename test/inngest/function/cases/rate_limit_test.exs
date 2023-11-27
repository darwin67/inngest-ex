defmodule Inngest.Function.Cases.RateLimitTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer
  import Inngest.Test.Helper

  @default_sleep 10_000

  @tag :integration
  test "should only run 2 out of 10" do
    event_ids = Enum.map(1..10, fn _ -> send_test_event("test/plug.ratelimit") end)

    Process.sleep(@default_sleep)

    fn_runs =
      event_ids
      |> Enum.map(fn id ->
        {:ok, %{"data" => data}} = DevServer.run_ids(id)

        if Enum.count(data) == 1 do
          assert [
                   %{
                     "output" => "Rate Limited",
                     "status" => "Completed",
                     "run_id" => run_id
                   }
                 ] = data
        else
          nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    assert Enum.count(fn_runs) <= 2
  end
end
