defmodule Inngest.Router.PlugTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer

  describe "no step fn" do
    test "should run successfully" do
      assert {:ok,
              %{
                "ids" => [event_id],
                "status" => 200
              }} = Inngest.send(%{name: "test/plug.no-step", data: %{}})

      Process.sleep(5000)

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

      Process.sleep(5000)

      assert {:ok, resp} = DevServer.run_ids(event_id) |> IO.inspect()
    end
  end
end
