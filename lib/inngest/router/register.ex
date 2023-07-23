defmodule Inngest.Router.Register do
  @moduledoc """
  The plug that handles registration request from Inngest
  """
  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.Config

  @content_type "application/json"

  defdelegate httpclient(type, opts), to: Inngest.Client

  @spec init(map()) :: map()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, opts), do: exec(conn, opts)

  defp exec(
         %{request_path: path} = conn,
         %{funcs: funcs, framework: framework} = _params
       ) do
    funcs = func_map(path, funcs)

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
      v: "1",
      deployType: "ping",
      sdk: Config.sdk_version(),
      framework: framework,
      appName: Config.app_name(),
      functions: functions |> Enum.map(fn {_, v} -> v.mod.serve(path) end)
    }

    key = Inngest.Signature.hashed_signing_key(Config.signing_key())
    headers = if is_nil(key), do: [], else: [authorization: "Bearer " <> key]

    headers =
      if is_nil(Config.inngest_env()),
        do: headers,
        else: Keyword.put(headers, :"x-inngest-env", Config.inngest_env())

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
