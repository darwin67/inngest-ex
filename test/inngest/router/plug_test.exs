defmodule Inngest.Router.PlugTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer

  # 5s
  @default_sleep 5_000

  describe "no step fn" do
    test "should run successfully" do
      assert {:ok,
              %{
                "ids" => [event_id],
                "status" => 200
              }} = Inngest.send(%{name: "test/plug.no-step", data: %{}})

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
      assert {:ok,
              %{
                "ids" => [event_id],
                "status" => 200
              }} = Inngest.send(%{name: "test/plug.step", data: %{}})

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
end
