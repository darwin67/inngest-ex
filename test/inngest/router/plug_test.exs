defmodule Inngest.Router.PlugTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer

  # 5s
  @default_sleep 5_000

  describe "no step fn" do
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

  describe "multi-step fn" do
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

  describe "sleep fn" do
    test "should run successfully" do
      event_id = send_test_event("test/plug.sleep")
      Process.sleep(@default_sleep)

      # it should be sleeping so have not completed
      assert {:ok,
              %{
                "data" => [
                  %{
                    "run_id" => run_id,
                    "status" => "Running",
                    "ended_at" => nil
                  }
                ]
              }} = DevServer.run_ids(event_id)

      # wait till sleep is done
      Process.sleep(@default_sleep)

      assert {:ok,
              %{
                "data" => %{
                  "event_id" => ^event_id,
                  "run_id" => ^run_id,
                  "output" => "yolo",
                  "status" => "Completed"
                }
              }} = DevServer.fn_run(run_id)
    end
  end

  defp send_test_event(event) do
    assert {:ok,
            %{
              "ids" => [event_id],
              "status" => 200
            }} = Inngest.send(%{name: event, data: %{}})

    event_id
  end
end
