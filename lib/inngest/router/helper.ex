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

  def load_functions_from_path(%{path: paths} = kv) when is_list(paths) do
    {:ok, modules, _warnings} =
      paths
      |> Enum.map(&Path.wildcard/1)
      |> List.flatten()
      |> Stream.filter(&(!File.dir?(&1)))
      |> Enum.uniq()
      |> Kernel.ParallelCompiler.compile()

    funcs = Map.get(kv, :funcs, [])
    Map.put(kv, :funcs, funcs ++ modules)
  end

  def load_functions_from_path(%{path: path} = kv) when is_binary(path) do
    {:ok, modules, _warnings} =
      path
      |> Path.wildcard()
      |> Enum.filter(&(!File.dir?(&1)))
      |> Kernel.ParallelCompiler.compile()

    funcs = Map.get(kv, :funcs, [])
    Map.put(kv, :funcs, funcs ++ modules)
  end

  def load_functions_from_path(kv), do: kv
end
