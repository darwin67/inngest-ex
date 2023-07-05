defmodule Inngest.Function.HandlerTest do
  use ExUnit.Case, async: true

  alias Inngest.{Event, Enums, TestEventFn}
  alias Inngest.Function.{Handler, GeneratorOpCode}

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

    @step1_hash "BD01C51E32280A0F2A0C50EFDA6B47AB1A685ED9"
    @step2_hash "AAB4F015B1D26D76C015B987F32E28E0869E7636"
    @step3_hash "C3C14E4F5420C304AF2FDEE2683C4E31E15B3CC2"
    @op Enums.opcode(:step_run)

    setup do
      %{
        handler: TestEventFn.__handler__(),
        args: %{event: @event, run_id: @run_id, params: @init_params}
      }
    end

    test "initial invoke returns result of 1st step", %{handler: handler, args: args} do
      assert {206, result} = Handler.invoke(handler, args)

      assert [
               %GeneratorOpCode{
                 op: @op,
                 id: @step1_hash,
                 name: "step1",
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

      assert [
               %GeneratorOpCode{
                 op: @op,
                 id: @step2_hash,
                 name: "step2",
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

      assert [
               %GeneratorOpCode{
                 op: @op,
                 id: @step3_hash,
                 name: "step3",
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
