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

    [
      "1ms",
      "5m later",
      "5minutes",
      "1s2",
      "0.5s",
      "duration 1m",
      " 1m",
      "1m ",
      "1m\n",
      "1h/30m",
      "1d2h"
    ]
    |> Enum.each(fn input ->
      test "should reject partial duration #{inspect(input)}" do
        assert {:error, "invalid duration: '#{unquote(input)}'"} =
                 Util.parse_duration(unquote(input))
      end
    end)
  end
end
