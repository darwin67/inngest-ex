defmodule Inngest.Router.PlugTest do
  use ExUnit.Case, async: true

  alias Inngest.Test.DevServer

  describe "no step fn" do
    test "should run successfully" do
      assert {:ok,
              %{
                "ids" => [event_id],
                "status" => 200
              }} = Inngest.send(%{name: "test/no-step", data: %{}})

      Process.sleep(2000)

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
end
