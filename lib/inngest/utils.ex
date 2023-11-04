defmodule Inngest.Utils do
  @doc """
  Convert all keys to atom for a map
  """
  @spec keys_to_atoms(map()) :: map()
  def keys_to_atoms(kv) when is_map(kv) do
    Map.new(kv, &reduce_keys_to_atoms/1)
  end

  defp reduce_keys_to_atoms({key, val}) when is_atom(key),
    do: {key, keys_to_atoms(val)}

  defp reduce_keys_to_atoms({key, val}) when is_map(val),
    do: {String.to_atom(key), keys_to_atoms(val)}

  defp reduce_keys_to_atoms({key, val}) when is_list(val),
    do: {String.to_atom(key), Enum.map(val, &keys_to_atoms(&1))}

  defp reduce_keys_to_atoms({key, val}), do: {String.to_atom(key), val}
end
