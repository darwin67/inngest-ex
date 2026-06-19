defmodule Inngest.Router.Register do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Client, Config, Headers, Signature}

  @content_type "application/json"

  @spec init(map()) :: map()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, opts), do: exec(conn, opts)

  defp exec(
         %{request_path: path} = conn,
         %{framework: framework} = params
       ) do
    {status, resp} = sync(conn, path, params, framework)

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, Jason.encode!(resp))
  end

  defp sync(conn, path, params, framework) do
    with :ok <- verify_signature(conn),
         {:ok, app_name} <- app_name(),
         funcs <- params |> load_functions() |> Enum.flat_map(& &1.serve(path)),
         {:ok, modified} <- register(conn, path, funcs, app_name, framework) do
      {200, %{message: "registered", modified: modified}}
    else
      {:error, :invalid_signature} ->
        {500, %{error: "unable to verify signature"}}

      {:error, error} ->
        {500, %{error: error}}
    end
  end

  defp register(conn, path, functions, app_name, framework) do
    payload = %{
      url: Config.serve_url(path),
      v: "0.1",
      deployType: "ping",
      sdk: Config.sdk_version(),
      framework: framework,
      appName: app_name,
      functions: functions
    }

    case Client.post(:register, register_path(conn), payload, headers: register_headers(conn)) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, registration_modified(body)}

      {:ok, %Tesla.Env{status: 201, body: body}} ->
        {:ok, registration_modified(body)}

      {:ok, %Tesla.Env{status: 202, body: body}} ->
        {:ok, registration_modified(body)}

      {:ok, %Tesla.Env{status: _, body: error}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end

  defp verify_signature(conn) do
    case get_req_header(conn, Headers.signature()) do
      [] ->
        :ok

      [signature | _] ->
        keys = [Config.signing_key(), Config.signing_key_fallback()]

        if Signature.signing_key_valid?(signature, keys, raw_body(conn)) do
          :ok
        else
          {:error, :invalid_signature}
        end
    end
  end

  defp app_name() do
    case Config.app_name() do
      name when is_binary(name) and name != "" -> {:ok, name}
      _ -> {:error, "appName must not be empty"}
    end
  end

  defp register_path(conn) do
    case Map.get(conn.params, "deployId") do
      nil -> "/fn/register"
      "" -> "/fn/register"
      deploy_id -> "/fn/register?" <> URI.encode_query(%{"deployId" => deploy_id})
    end
  end

  defp registration_modified(%{"modified" => modified}) when is_boolean(modified), do: modified
  defp registration_modified(%{modified: modified}) when is_boolean(modified), do: modified
  defp registration_modified(_body), do: true

  defp register_headers(conn) do
    case get_req_header(conn, Headers.server_kind()) do
      [] -> []
      [server_kind | _] -> [{Headers.expected_server_kind(), server_kind}]
    end
  end

  defp raw_body(%{private: %{raw_body: body}}) when is_list(body), do: Enum.join(body)
  defp raw_body(_conn), do: ""
end
