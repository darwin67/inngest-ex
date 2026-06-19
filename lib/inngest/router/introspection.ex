defmodule Inngest.Router.Introspection do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Config, Headers, Signature}

  @content_type "application/json"
  @schema_version "2024-05-24"
  @sdk_language "elixir"

  @spec init(map()) :: map()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, opts) do
    funcs = load_functions(opts)
    framework = Map.get(opts, :framework)

    {status, resp} =
      case authentication(conn) do
        :unsigned ->
          {200, unauthenticated_response(funcs, nil)}

        :invalid ->
          {200, unauthenticated_response(funcs, false)}

        :valid ->
          authenticated_response(conn, funcs, framework)
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, Jason.encode!(resp))
  end

  defp authentication(conn) do
    case get_req_header(conn, Headers.signature()) do
      [] ->
        :unsigned

      [signature | _] ->
        keys = [Config.signing_key(), Config.signing_key_fallback()]

        if Signature.signing_key_valid?(signature, keys, raw_body(conn)) do
          :valid
        else
          :invalid
        end
    end
  end

  defp unauthenticated_response(funcs, authentication_succeeded) do
    %{
      authentication_succeeded: authentication_succeeded,
      function_count: length(funcs),
      has_event_key: configured?(Config.event_key()),
      has_signing_key: signing_key?(Config.signing_key()),
      has_signing_key_fallback: signing_key?(Config.signing_key_fallback()),
      mode: mode(),
      schema_version: @schema_version
    }
  end

  defp authenticated_response(conn, funcs, framework) do
    case app_id() do
      {:ok, app_id} ->
        {200,
         %{
           api_origin: Config.api_url(),
           app_id: app_id,
           authentication_succeeded: true,
           env: Config.inngest_env(),
           event_api_origin: Config.event_url(),
           event_key_hash: hash(Config.event_key()),
           framework: framework,
           function_count: length(funcs),
           has_event_key: configured?(Config.event_key()),
           has_signing_key: signing_key?(Config.signing_key()),
           has_signing_key_fallback: signing_key?(Config.signing_key_fallback()),
           mode: mode(),
           schema_version: @schema_version,
           sdk_language: @sdk_language,
           sdk_version: Config.sdk_version(),
           serve_origin: Config.app_host(),
           serve_path: Config.serve_path() || conn.request_path,
           signing_key_fallback_hash: Signature.hashed_signing_key(Config.signing_key_fallback()),
           signing_key_hash: Signature.hashed_signing_key(Config.signing_key())
         }}

      {:error, error} ->
        {500, %{error: error}}
    end
  end

  defp app_id do
    case Config.app_name() do
      app_id when is_binary(app_id) and app_id != "" -> {:ok, app_id}
      _ -> {:error, "app_id must not be empty"}
    end
  end

  defp configured?(value), do: is_binary(value) and value != ""

  defp signing_key?(value), do: not is_nil(Signature.hashed_signing_key(value))

  defp hash(value) do
    if configured?(value) do
      :crypto.hash(:sha256, value)
      |> Base.encode16(case: :lower)
    end
  end

  defp mode, do: Config.mode() |> Atom.to_string()

  defp raw_body(%{private: %{raw_body: body}}) when is_list(body), do: Enum.join(body)
  defp raw_body(_conn), do: ""
end
