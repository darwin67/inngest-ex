defmodule Inngest.Util do
  @moduledoc """
  Utility functions
  """

  @doc """
  Parse string duration that Inngest understands into seconds
  """
  @spec parse_duration(binary()) :: {:ok, number()} | {:error, binary()}
  def parse_duration(value) do
    with [_, num, unit] <- Regex.run(~r/(\d+)(s|m|h|d)/i, value),
         dur <- String.to_integer(num) do
      case unit do
        "d" -> {:ok, dur * day_in_seconds()}
        "h" -> {:ok, dur * hour_in_seconds()}
        "m" -> {:ok, dur * minute_in_seconds()}
        "s" -> {:ok, dur}
        _ -> {:error, "invalid time unit '#{unit}', must be d|h|m|s"}
      end
    else
      nil ->
        {:error, "invalid duration: '#{value}'"}

      _ ->
        {:error, "unknow error occurred when parsing duration"}
    end
  end

  def day_in_seconds(), do: 60 * 60 * 24
  def hour_in_seconds(), do: 60 * 60
  def minute_in_seconds(), do: 60
end
