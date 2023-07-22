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

  @spec signing_key_valid?(binary(), binary(), binary(), keyword()) :: boolean()
  def signing_key_valid?(sig, key, body, opts \\ [])

  def signing_key_valid?(sig, key, body, opts)
      when is_binary(sig) and is_binary(key) and is_binary(body) do
    with %{"s" => _sig, "t" => timestamp} <- Plug.Conn.Query.decode(sig),
         {unix_ts, ""} <- Integer.parse(timestamp),
         within_timeframe <-
           Timex.from_unix(unix_ts, :millisecond) in Timex.Interval.new(
             from: Timex.shift(Timex.now(), minutes: -5),
             until: Timex.now()
           ),
         ignore_ts <- Keyword.get(opts, :ignore_ts, false) do
      if within_timeframe || ignore_ts do
        sig == sign(timestamp, key, body)
      else
        false
      end
    else
      _ -> false
    end
  end

  def signing_key_valid?(_, _, _, _), do: false

  def sign(unix_ts, signing_key, body)
      when is_binary(unix_ts) and is_binary(signing_key) and is_binary(body) do
    with key <- normalize_key(signing_key),
         sig <- :crypto.mac(:hmac, :sha256, key, body <> unix_ts) |> Base.encode16(case: :lower) do
      "t=#{unix_ts}&s=#{sig}"
    else
      _ -> ""
    end
  end

  def sign(unix_ts, signing_key, body)
      when is_number(unix_ts) and is_binary(signing_key) and is_map(body),
      do:
        unix_ts
        |> Integer.to_string()
        |> sign(signing_key, body)

  def sign(_, _, _), do: ""

  def normalize_key(key), do: Regex.replace(~r/^(signkey-.+-)/, key, "")
end
