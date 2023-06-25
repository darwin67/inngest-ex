defmodule Inngest.HandlerTest do
  use ExUnit.Case, async: true

  alias Inngest.{Handler, TestEventFn}

  describe "invoke/3" do
    setup do
      %{
        conn: Plug.Test.conn(:get, "/", nil),
        func: TestEventFn.serve()
      }
    end

    test "only 1st step should execute on inital run", %{conn: conn, func: f} do
      assert {200, result} = Handler.invoke(conn, f, %{})

      assert %{
               "fn_count" => 1,
               "step1_count" => 1,
               "step2_count" => 0
             } = Jason.decode!(result)
    end

    test "2nd step should execute with 1st step data", %{conn: conn, func: f} do
      assert {200, result} = Handler.invoke(conn, f, %{})

      assert %{
               "fn_count" => 2,
               "step1_count" => 1,
               "step2_count" => 1
             } = Jason.decode!(result)
    end
  end
end
