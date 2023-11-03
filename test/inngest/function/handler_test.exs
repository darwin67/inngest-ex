# defmodule Inngest.Function.HandlerTest do
#   use ExUnit.Case, async: true

#   alias Inngest.{Event, Enums, TestEventFn}
#   alias Inngest.Function.GeneratorOpCode

#   describe "invoke/2" do
#     @run_id "01H4E9105QZNAZHGFRF14VCE2K"
#     @init_params %{
#       "ctx" => %{
#         "env" => "local",
#         "fn_id" => "dce563f1-ee74-4d68-b8b0-86de91c5a83f",
#         "run_id" => @run_id,
#         "stack" => %{
#           "current" => 0,
#           "stack" => []
#         }
#       },
#       "steps" => %{}
#     }
#     @event %Event{name: "test event", data: %{"yo" => "lo"}}

#     @step1_hash "BD01C51E32280A0F2A0C50EFDA6B47AB1A685ED9"
#     @step2_hash "AAB4F015B1D26D76C015B987F32E28E0869E7636"
#     @step3_hash "C3C14E4F5420C304AF2FDEE2683C4E31E15B3CC2"
#     @step4_hash "EC9FE031264AB8889294A32EC361BB9412ACDBD1"
#     @step5_hash "0B16CEB48DB1E67131278943647BAB213494B636"

#     @sleep1_hash "145E2844A2497AB79D89CAFF7C8CCA0CC7F114AE"
#     @sleep2_hash "D924BC0E9DE36100A8DB3B932934FFE9357BBC46"
#     @sleep_until_hash "8FD581C437A99A584B0186168DB25F8D8AF7D6B5"

#     setup do
#       %{
#         handler: TestEventFn.__handler__(),
#         args: %{event: @event, run_id: @run_id, params: @init_params}
#       }
#     end

#     test "initial invoke returns result of 1st step", %{handler: handler, args: args} do
#       assert {206, result} = Handler.invoke(handler, args)
#       opcode = Enums.opcode(:step_run)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @step1_hash,
#                  name: "step1",
#                  data: %{
#                    run: "something",
#                    step: "hello world",
#                    fn_count: 1,
#                    step1_count: 1,
#                    step2_count: 0
#                  }
#                }
#              ] = result
#     end

#     test "2nd invoke returns 2s sleep", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         }
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 1)
#         |> put_in([:params, "ctx", "stack", "stack"], [@step1_hash])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_sleep)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @sleep1_hash,
#                  name: "2s",
#                  data: nil
#                }
#              ] = result
#     end

#     test "3rd invoke returns result of 2nd step", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @sleep1_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 2)
#         |> put_in([:params, "ctx", "stack", "stack"], [@step1_hash, @sleep1_hash])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_run)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @step2_hash,
#                  name: "step2",
#                  data: %{
#                    step: "yolo",
#                    fn_count: 2,
#                    step1_count: 1,
#                    step2_count: 1
#                  }
#                }
#              ] = result
#     end

#     test "4th invoke returns another 3s sleep", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @sleep1_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 3)
#         |> put_in([:params, "ctx", "stack", "stack"], [@step1_hash, @sleep1_hash, @step2_hash])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_sleep)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @sleep2_hash,
#                  name: "3s",
#                  data: nil
#                }
#              ] = result
#     end

#     test "5th invoke returns sleep until", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @sleep1_hash => nil,
#         @sleep2_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 4)
#         |> put_in([:params, "ctx", "stack", "stack"], [
#           @step1_hash,
#           @sleep1_hash,
#           @step2_hash,
#           @sleep2_hash
#         ])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_sleep)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @sleep_until_hash,
#                  name: "2023-07-12T06:35:00Z",
#                  data: nil
#                }
#              ] = result
#     end

#     test "6th invoke returns result of 3rd step", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @sleep1_hash => nil,
#         @sleep2_hash => nil,
#         @sleep_until_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 5)
#         |> put_in([:params, "ctx", "stack", "stack"], [
#           @step1_hash,
#           @sleep1_hash,
#           @step2_hash,
#           @sleep2_hash,
#           @sleep_until_hash
#         ])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_run)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @step3_hash,
#                  name: "step3",
#                  data: %{
#                    step: "final",
#                    fn_count: 3,
#                    step1_count: 1,
#                    step2_count: 1,
#                    run: "again"
#                  }
#                }
#              ] = result
#     end

#     test "7th invoke returns result of step 4", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @step3_hash => %{
#           step: "final",
#           fn_count: 3,
#           step1_count: 1,
#           step2_count: 1,
#           run: "again"
#         },
#         @sleep1_hash => nil,
#         @sleep2_hash => nil,
#         @sleep_until_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 6)
#         |> put_in([:params, "ctx", "stack", "stack"], [
#           @step1_hash,
#           @sleep1_hash,
#           @step2_hash,
#           @sleep2_hash,
#           @sleep_until_hash,
#           @step3_hash
#         ])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_run)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @step4_hash,
#                  name: "step4",
#                  data: "foobar"
#                }
#              ] = result
#     end

#     test "8th invoke returns result of step 5", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @step3_hash => %{
#           step: "final",
#           fn_count: 3,
#           step1_count: 1,
#           step2_count: 1,
#           run: "again"
#         },
#         @step4_hash => "foobar",
#         @sleep1_hash => nil,
#         @sleep2_hash => nil,
#         @sleep_until_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 7)
#         |> put_in([:params, "ctx", "stack", "stack"], [
#           @step1_hash,
#           @sleep1_hash,
#           @step2_hash,
#           @sleep2_hash,
#           @sleep_until_hash,
#           @step3_hash,
#           @step4_hash
#         ])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_run)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @step5_hash,
#                  name: "step5",
#                  data: nil
#                }
#              ] = result
#     end

#     test "9th invoke returns result of remaining run", %{handler: handler, args: args} do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @step3_hash => %{
#           step: "final",
#           fn_count: 3,
#           step1_count: 1,
#           step2_count: 1,
#           run: "again"
#         },
#         @step4_hash => "foobar",
#         @step5_hash => nil,
#         @sleep1_hash => nil,
#         @sleep2_hash => nil,
#         @sleep_until_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 8)
#         |> put_in([:params, "ctx", "stack", "stack"], [
#           @step1_hash,
#           @sleep1_hash,
#           @step2_hash,
#           @sleep2_hash,
#           @sleep_until_hash,
#           @step3_hash,
#           @step4_hash,
#           @step5_hash
#         ])
#         |> put_in([:params, "steps"], current_state)

#       # Invoke
#       assert {200, result} = Handler.invoke(handler, args)

#       assert %{
#                "step4" => "foobar",
#                step: "final",
#                fn_count: 4,
#                step1_count: 1,
#                step2_count: 1,
#                run: "again",
#                yo: "lo"
#              } = result
#     end

#     test "ignore step2 hash and execute sleep 2s due to stack out of order", %{
#       handler: handler,
#       args: args
#     } do
#       # return data from step 1
#       current_state = %{
#         @step1_hash => %{
#           step: "hello world",
#           fn_count: 1,
#           step1_count: 1,
#           step2_count: 0
#         },
#         @step2_hash => %{
#           step: "yolo",
#           fn_count: 2,
#           step1_count: 1,
#           step2_count: 1
#         },
#         @sleep1_hash => nil
#       }

#       args =
#         args
#         |> put_in([:params, "ctx", "stack", "current"], 3)
#         |> put_in([:params, "ctx", "stack", "stack"], [@step1_hash, @step2_hash, @sleep1_hash])
#         |> put_in([:params, "steps"], current_state)

#       opcode = Enums.opcode(:step_sleep)

#       # Invoke
#       assert {206, result} = Handler.invoke(handler, args)

#       assert [
#                %GeneratorOpCode{
#                  op: ^opcode,
#                  id: @sleep1_hash,
#                  name: "2s",
#                  data: nil
#                }
#              ] = result
#     end
#   end
# end
