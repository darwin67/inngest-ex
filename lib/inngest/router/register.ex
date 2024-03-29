defmodule Inngest.Router.Register do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Config, Headers}

  @content_type "application/json"

  defdelegate httpclient(type, opts), to: Inngest.Client

  @spec init(map()) :: map()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, opts), do: exec(conn, opts)

  defp exec(
         %{request_path: path} = conn,
         %{framework: framework} = params
       ) do
    funcs =
      params
      |> load_functions()
      |> Enum.flat_map(& &1.serve(path))

    {status, resp} =
      case register(path, funcs, framework: framework) do
        :ok ->
          {200, %{}}

        {:error, error} ->
          {400, error}
      end

    resp =
      case Jason.encode(resp) do
        {:ok, val} -> val
        {:error, error} -> error
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, resp)
  end

  defp register(path, functions, opts) do
    framework = Keyword.get(opts, :framework)

    payload = %{
      url: Config.app_host() <> path,
      v: "0.1",
      deployType: "ping",
      sdk: Config.sdk_version(),
      framework: framework,
      appName: Config.app_name(),
      functions: functions
    }

    key = Inngest.Signature.hashed_signing_key(Config.signing_key())
    headers = if is_nil(key), do: [], else: [authorization: "Bearer " <> key]

    headers =
      if is_nil(Config.env()),
        do: headers,
        else: Keyword.put(headers, String.to_atom(Headers.env()), Config.env())

    case Tesla.post(httpclient(:register, headers: headers), "/fn/register", payload) do
      {:ok, %Tesla.Env{status: 200}} ->
        :ok

      {:ok, %Tesla.Env{status: 201}} ->
        :ok

      {:ok, %Tesla.Env{status: 202}} ->
        :ok

      {:ok, %Tesla.Env{status: _, body: error}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end
end
