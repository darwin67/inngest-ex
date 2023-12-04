defmodule Inngest.Function.UnhashedOpTest do
  use ExUnit.Case, async: true

  alias Inngest.Function.UnhashedOp

  describe "new/3" do
    setup do
      %{table: :ets.new(:sample, [:set, :private])}
    end

    test "should create unhashed op with 0 idx if ID doesn't exist", %{table: table} do
      ctx = %{index: table}
      id = "hello"
      op = "Step"

      assert %UnhashedOp{
               id: ^id,
               op: ^op,
               pos: 0,
               opts: %{}
             } = UnhashedOp.new(ctx, op, id)
    end

    test "should create unhashed op with incremented idx if ID already exist", %{table: table} do
      ctx = %{index: table}
      id = "hello"
      op = "Step"
      :ets.insert(table, {id, 0})

      assert %UnhashedOp{
               id: ^id,
               op: ^op,
               pos: 1,
               opts: %{}
             } = UnhashedOp.new(ctx, op, id)
    end
  end

  describe "hash/1" do
    setup do
      %{
        op: %UnhashedOp{id: "hello", op: "Step", pos: 0, opts: %{}}
      }
    end

    test "should only hash with ID if pos == 0", %{op: op} do
      expected = :crypto.hash(:sha, "hello") |> Base.encode16()
      assert ^expected = UnhashedOp.hash(op)
    end

    test "should hash with idx if pos > 0", %{op: op} do
      op = %{op | pos: 1}
      expected = :crypto.hash(:sha, "hello:1") |> Base.encode16()
      assert ^expected = UnhashedOp.hash(op)
    end
  end
end
