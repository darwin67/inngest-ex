defmodule Inngest.Function.HandlerTest do
  use ExUnit.Case, async: true

  alias Inngest.Event
  alias Inngest.Function.{Handler, GeneratorOpCode, OpCode}
  alias Inngest.TestEventFn

  describe "invoke/2" do
    @run_id "01H4E9105QZNAZHGFRF14VCE2K"
    @init_params %{
      "ctx" => %{
        "env" => "local",
        "fn_id" => "dce563f1-ee74-4d68-b8b0-86de91c5a83f",
        "run_id" => @run_id,
        "stack" => %{
          "current" => 0,
          "stack" => []
        }
      },
      "steps" => %{}
    }
    @event %Event{name: "test event", data: %{"yo" => "lo"}}

    @step1_hash "D7573B282133611D94397905FAE32EB6AE45FA05"
    @step2_hash "8C04C8CD6DE995809D6AD0D04325358E88211027"
    @step3_hash "E72FB021F48D701CE33B0DB74DCA48ECEED86D4E"

    setup do
      %{
        handler: TestEventFn.__handler__(),
        args: %{event: @event, run_id: @run_id, params: @init_params}
      }
    end

    test "initial invoke returns result of 1st step", %{handler: handler, args: args} do
      assert {206, result} = Handler.invoke(handler, args)

      op = OpCode.enum(:step_run)

      assert [
               %GeneratorOpCode{
                 op: ^op,
                 id: @step1_hash,
                 name: "step1",
                 opts: %{},
                 data: %{
                   step: "hello world",
                   fn_count: 1,
                   step1_count: 1,
                   step2_count: 0
                 }
               }
             ] = result
    end

    test "2nd invoke returns result of 2nd step", %{handler: handler, args: args} do
      # return data from step 1
      current_state = %{
        @step1_hash => %{
          step: "hello world",
          fn_count: 1,
          step1_count: 1,
          step2_count: 0
        }
      }

      args =
        args
        |> put_in([:params, "ctx", "stack", "stack"], [@step1_hash])
        |> put_in([:params, "steps"], current_state)

      # Invoke
      assert {206, result} = Handler.invoke(handler, args)
      op = OpCode.enum(:step_run)

      assert [
               %GeneratorOpCode{
                 op: ^op,
                 id: @step2_hash,
                 name: "step2",
                 opts: %{},
                 data: %{
                   step: "yolo",
                   fn_count: 2,
                   step1_count: 1,
                   step2_count: 1
                 }
               }
             ] = result
    end

    test "3rd invoke returns result of 3rd step", %{handler: handler, args: args} do
      # return data from step 1
      current_state = %{
        @step1_hash => %{
          step: "hello world",
          fn_count: 1,
          step1_count: 1,
          step2_count: 0
        },
        @step2_hash => %{
          step: "yolo",
          fn_count: 2,
          step1_count: 1,
          step2_count: 1
        }
      }

      args =
        args
        |> put_in([:params, "ctx", "stack", "stack"], [@step1_hash, @step2_hash])
        |> put_in([:params, "steps"], current_state)

      # Invoke
      assert {206, result} = Handler.invoke(handler, args)
      op = OpCode.enum(:step_run)

      assert [
               %GeneratorOpCode{
                 op: ^op,
                 id: @step3_hash,
                 name: "step3",
                 opts: %{},
                 data: %{
                   step: "final",
                   fn_count: 3,
                   step1_count: 1,
                   step2_count: 1
                 }
               }
             ] = result
    end
  end
end
