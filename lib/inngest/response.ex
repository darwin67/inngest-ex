defmodule Inngest.SdkResponse do
  @moduledoc false

  defstruct [
    :status,
    :body,
    retry: true
  ]

  @type t() :: %__MODULE__{
          status: number(),
          body: binary(),
          # string is for seconds to be delayed
          retry: boolean() | number()
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

  def from_result({:ok, opcodes}, continue: true) do
    %__MODULE__{
      status: 206,
      body: Jason.encode!(opcodes)
    }
  end

  def from_result({:ok, value}, _opts) do
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

  def from_result({:error, error}, opts) do
    stacktrace = Keyword.get(opts, :stacktrace, [])
    retry = Keyword.get(opts, :retry, true)
    status = if retry, do: 500, else: 400

    encoded =
      case Exception.format(:error, error, stacktrace) |> Jason.encode() do
        {:ok, encoded} -> encoded
        {:error, _} -> "Failed to encode error: #{error}"
      end

    %__MODULE__{
      status: status,
      body: encoded,
      retry: retry
    }
  end

  def from_result(_, _),
    do: %__MODULE__{
      status: 400,
      body: "Unknown result",
      retry: true
    }

  @doc """
  Set the retry header depending on response
  """
  @spec maybe_retry_header(Plug.Conn.t(), t()) :: Plug.Conn.t()
  def maybe_retry_header(conn, %{retry: false} = _resp) do
    Plug.Conn.put_resp_header(conn, Headers.no_retry(), "true")
  end

  def maybe_retry_header(conn, %{retry: dur} = _resp) when is_number(dur) do
    Plug.Conn.put_resp_header(conn, Headers.retry_after(), to_string(dur))
  end

  def maybe_retry_header(conn, _resp), do: conn
end
