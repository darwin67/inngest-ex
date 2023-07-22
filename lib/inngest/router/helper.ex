defmodule Inngest.Router.Helper do
  @moduledoc """
  Helper module for router and plugs
  """

  @spec func_map(binary(), list()) :: map()
  def func_map(path, funcs) do
    funcs
    |> Enum.reduce(%{}, fn func, x ->
      slug = func.slug()
      Map.put(x, slug, func.serve(path))
    end)
  end
end
