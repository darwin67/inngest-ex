defmodule Inngest.Router.Helper do
  @moduledoc false

  @spec func_map(binary(), list()) :: map()
  def func_map(path, funcs) do
    funcs
    |> Enum.reduce(%{}, fn func, x ->
      slug = func.slug()
      Map.put(x, slug, func.serve(path))
    end)
  end

  @spec load_functions_from_path(map()) :: map()
  def load_functions_from_path(%{path: paths} = kv) when is_list(paths) do
    modules =
      paths
      |> Enum.map(&Path.wildcard/1)
      |> List.flatten()
      |> Stream.filter(&(!File.dir?(&1)))
      |> Enum.uniq()
      |> extract_modules()

    funcs = Map.get(kv, :funcs, [])
    Map.put(kv, :funcs, funcs ++ modules)
  end

  def load_functions_from_path(%{path: path} = kv) when is_binary(path) do
    modules =
      path
      |> Path.wildcard()
      |> Enum.filter(&(!File.dir?(&1)))
      |> extract_modules()

    funcs = Map.get(kv, :funcs, [])
    Map.put(kv, :funcs, funcs ++ modules)
  end

  def load_functions_from_path(kv), do: kv

  defp extract_modules(files) do
    files
    |> Enum.flat_map(fn file ->
      with {:ok, content} <- File.read(file),
           {:ok, ast} = Code.string_to_quoted(content) do
        module_names(ast)
      else
        _ -> []
      end
    end)
  end

  defp module_names({:__block__, _, mods}), do: Enum.flat_map(mods, &module_names/1)

  defp module_names({:defmodule, _line, [{_, _, module}, _body]}),
    do: [Module.concat(module)]
end
