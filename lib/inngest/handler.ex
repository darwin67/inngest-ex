defmodule Inngest.Handler do
  @moduledoc """
  Handler takes care of managing function state and invoking user functions
  """

  def invoke(_conn, func, args) do
    {status, result} =
      case func.mod.perform(args) do
        {:ok, res} -> {200, res}
        {:error, error} -> {400, error}
      end

    payload =
      case Jason.encode(result) do
        {:ok, val} -> val
        {:error, err} -> Jason.encode!(err.message)
      end

    {status, payload}
  end
end
