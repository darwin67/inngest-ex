defmodule Inngest.Signature do
  @moduledoc """
  Handles signature related operations
  """
  @spec hashed_signing_key(binary()) :: binary() | nil
  def hashed_signing_key(signing_key) do
    with %{"prefix" => prefix} <- Regex.named_captures(~r/^(?<prefix>signkey-.+-)/, signing_key),
         key <- Regex.replace(~r/^(signkey-.+-)/, signing_key, ""),
         {:ok, dst} <- Base.decode16(key, case: :lower),
         sum <- :crypto.hash(:sha256, dst),
         enc <- Base.encode16(sum, case: :lower) do
      prefix <> enc
    else
      _ -> nil
    end
  end

  @spec siging_key_valid?(binary() | nil) :: boolean()
  def siging_key_valid?(sig) when is_binary(sig) do
    true
  end

  def signing_key_valid?(_), do: false
end
