defmodule Inngest.StepToolTest do
  use ExUnit.Case, async: true

  alias Inngest.Function.GeneratorOpCode
  alias Inngest.StepTool

  describe "run/3" do
    test "reports an immediately executed run step when allowed" do
      assert %GeneratorOpCode{
               id: id,
               op: "StepRun",
               data: %{"ok" => true},
               display_name: "first"
             } =
               catch_throw(StepTool.run(ctx(), "first", fn -> %{"ok" => true} end))

      assert id == hash("first")
    end

    test "plans a run step when immediate execution is disabled" do
      assert %GeneratorOpCode{
               id: id,
               op: "StepPlanned",
               data: nil,
               display_name: "first"
             } =
               catch_throw(
                 StepTool.run(ctx(disable_immediate_execution: true), "first", fn ->
                   flunk("step body should not run")
                 end)
               )

      assert id == hash("first")
    end

    test "unwraps memoized run step data" do
      ctx = ctx(steps: %{hash("first") => %{"data" => "memoized"}})

      assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end) ==
               "memoized"
    end

    test "raises a step error for memoized run step errors" do
      error = %{"name" => "RuntimeError", "message" => "boom", "stack" => "stack"}
      ctx = ctx(steps: %{hash("first") => %{"error" => error}})

      assert_raise Inngest.StepError, "boom", fn ->
        StepTool.run(ctx, "first", fn -> flunk("step body should not run") end)
      end
    end

    test "raises a step error for unsupported legacy raw run step data" do
      ctx = ctx(steps: %{hash("first") => "legacy"})

      assert_raise Inngest.StepError, ~r/invalid memoized step data/, fn ->
        StepTool.run(ctx, "first", fn -> flunk("step body should not run") end)
      end
    end

    test "runs a targeted hashed step after memoized prior steps" do
      ctx =
        ctx(
          target_step_id: hash("second"),
          stack: %{"current" => 1, "stack" => [hash("first"), hash("second")]},
          steps: %{hash("first") => %{"data" => "memoized"}}
        )

      assert StepTool.run(ctx, "first", fn -> flunk("first step should be memoized") end) ==
               "memoized"

      assert %GeneratorOpCode{
               id: id,
               op: "StepRun",
               data: "target",
               display_name: "second"
             } = catch_throw(StepTool.run(ctx, "second", fn -> "target" end))

      assert id == hash("second")
    end

    test "returns StepNotFound instead of executing unrelated steps during targeted execution" do
      target_step_id = hash("second")

      assert %GeneratorOpCode{id: ^target_step_id, op: "StepNotFound"} =
               catch_throw(
                 StepTool.run(ctx(target_step_id: target_step_id), "first", fn ->
                   flunk("unrelated step body should not run")
                 end)
               )
    end

    test "reports step body failures as StepError" do
      assert %GeneratorOpCode{
               id: id,
               op: "StepError",
               error: %{name: "RuntimeError", message: "boom"},
               display_name: "first"
             } =
               catch_throw(
                 StepTool.run(ctx(), "first", fn ->
                   raise "boom"
                 end)
               )

      assert id == hash("first")
    end

    test "encodes run step nil results as data null and omits internal fields" do
      opcode = catch_throw(StepTool.run(ctx(), "first", fn -> nil end))

      assert Jason.decode!(Jason.encode!(opcode)) == %{
               "id" => hash("first"),
               "op" => "StepRun",
               "displayName" => "first",
               "data" => nil
             }
    end
  end

  describe "sleep/3" do
    test "reports sleep duration in opts" do
      assert %GeneratorOpCode{
               id: id,
               op: "Sleep",
               opts: %{duration: "10s"},
               display_name: "wait"
             } = catch_throw(StepTool.sleep(ctx(), "wait", "10s"))

      assert id == hash("wait")
    end

    test "preserves nil memoized sleep values" do
      assert StepTool.sleep(ctx(steps: %{hash("wait") => nil}), "wait", "10s") == nil
    end
  end

  defp ctx(attrs \\ []) do
    defaults = %{
      attempt: 0,
      run_id: "run-1",
      disable_immediate_execution: false,
      stack: nil,
      target_step_id: "step",
      steps: %{},
      index: :ets.new(:index, [:set, :private])
    }

    struct!(Inngest.Function.Context, Map.merge(defaults, Map.new(attrs)))
  end

  defp hash(id), do: :crypto.hash(:sha, id) |> Base.encode16()
end
