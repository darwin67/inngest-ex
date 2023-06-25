defmodule Inngest.Handler do
  @moduledoc """
  Handler takes care of managing function state and invoking user functions
  """

  def invoke(_conn, func, args) do
    {status, result} =
      case func.mod.perform(args) do
        {:ok, res} -> {200, res}
        {:error, error} -> {400, error}
        _ -> {400, "Unknown exit status"}
      end

    payload =
      case Jason.encode(result) do
        {:ok, val} -> val
        {:error, err} -> Jason.encode!(err.message)
      end

    {status, payload}
  end
end
