defmodule Inngest.UtilTest do
  use ExUnit.Case, async: true

  alias Inngest.Util

  describe "parse_duration/1" do
    %{
      "10s" => 10,
      "20m" => 20 * Util.minute_in_seconds(),
      "2h" => 2 * Util.hour_in_seconds(),
      "7d" => 7 * Util.day_in_seconds()
    }
    |> Enum.map(fn {key, val} -> {key, Macro.escape(val)} end)
    |> Enum.each(fn {input, expected} ->
      test "should succeed for #{input}" do
        output = unquote(expected)
        assert {:ok, ^output} = Util.parse_duration(unquote(input))
      end
    end)

    test "should fail for invalid duration" do
      assert {:error, "invalid duration: 'foobar'"} = Util.parse_duration("foobar")
    end

    test "should fail for invalid time units" do
      assert {:error, "invalid duration: '1y'"} = Util.parse_duration("1y")
    end
  end
end
