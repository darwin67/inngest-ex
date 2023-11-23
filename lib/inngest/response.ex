defmodule Inngest.NonRetriableError do
  defexception message: "Not retrying error. Exiting."
end

defmodule Inngest.SdkResponse do
  @moduledoc """
  Represents an SDK response to the executor when ran
  """

  defstruct [
    :status,
    :body,
    :retry
  ]

  @type t() :: %__MODULE__{
          status: number(),
          body: binary(),
          retry: nil | :noretry | binary() | boolean()
        }

  alias Inngest.Headers

  # NOTES:
  # *********  RESPONSE  ***********
  # Each results has a specific meaning to it.
  # status, data
  # 206, generatorcode -> store result and continue execution
  # 200, resp -> execution completed (including steps) of function
  # 400, error -> non retriable error
  # 500, error -> retriable error
  def from_result({:ok, value}) do
    case Jason.encode(value) do
      {:ok, encoded} ->
        %__MODULE__{
          status: 200,
          body: encoded
        }

      {:error, _error} ->
        %__MODULE__{
          status: 500,
          body: "Failed to encode result into JSON: #{value}"
        }
    end
  end

  def from_result({:ok, opcodes, :continue}) do
    %__MODULE__{
      status: 206,
      body: Jason.encode!(opcodes)
    }
  end

  # No retry error response
  def from_result({:error, error, :noretry}) do
    encoded =
      case Jason.encode(error) do
        {:ok, encoded} -> encoded
        {:error, _} -> "Failed to encode error: #{error}"
      end

    %__MODULE__{
      status: 400,
      body: encoded,
      retry: :noretry
    }
  end

  def from_result({:error, error, _}) do
    encoded =
      case Jason.encode(error) do
        {:ok, encoded} -> encoded
        {:error, _} -> "Failed to encode error: #{error}"
      end

    %__MODULE__{
      status: 500,
      body: encoded,
      retry: true
    }
  end

  @doc """
  Set the retry header depending on response
  """
  @spec maybe_retry_header(Plug.Conn.t(), t()) :: Plug.Conn.t()
  def maybe_retry_header(conn, %{retry: :noretry} = _resp) do
    Plug.Conn.put_resp_header(conn, Headers.no_retry(), "true")
  end

  def maybe_retry_header(conn, %{retry: dur} = _resp) when is_binary(dur) do
    Plug.Conn.put_resp_header(conn, Headers.retry_after(), dur)
  end

  def maybe_retry_header(conn, _resp), do: conn
end
