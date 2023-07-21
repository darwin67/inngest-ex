defmodule Inngest.Signature do
  @moduledoc """
  Handles signature related operations
  """
  @spec hashed_signing_key(binary()) :: binary() | nil
  def hashed_signing_key(signing_key) do
    with %{"prefix" => prefix} <- Regex.named_captures(~r/^(?<prefix>signkey-.+-)/, signing_key),
         key <- normalize_key(signing_key),
         {:ok, dst} <- Base.decode16(key, case: :lower),
         sum <- :crypto.hash(:sha256, dst),
         enc <- Base.encode16(sum, case: :lower) do
      prefix <> enc
    else
      _ -> nil
    end
  end

  @spec signing_key_valid?(binary(), map()) :: boolean()
  def signing_key_valid?(sig, body) when is_binary(sig) do
    true
  end

  def signing_key_valid?(_, _), do: false

  def normalize_key(key), do: Regex.replace(~r/^(signkey-.+-)/, key, "")
end
