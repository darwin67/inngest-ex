defmodule Inngest.Router.Introspection do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Headers, Signature}

  @content_type "application/json"
  @schema_version "2024-05-24"
  @sdk_language "elixir"

  @spec init(map()) :: map()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, opts) do
    client = client!(opts)
    framework = Map.get(opts, :framework)

    {status, resp} =
      case authentication(conn, client) do
        :unsigned ->
          {200, unauthenticated_response(client, nil)}

        :invalid ->
          {200, unauthenticated_response(client, false)}

        :valid ->
          authenticated_response(conn, client, framework)
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, Jason.encode!(resp))
  end

  defp authentication(conn, client) do
    case get_req_header(conn, Headers.signature()) do
      [] ->
        :unsigned

      [signature | _] ->
        keys = [client.signing_key, client.signing_key_fallback]

        if Signature.signing_key_valid?(signature, keys, raw_body(conn)) do
          :valid
        else
          :invalid
        end
    end
  end

  defp unauthenticated_response(client, authentication_succeeded) do
    %{
      authentication_succeeded: authentication_succeeded,
      function_count: length(client.funcs),
      has_event_key: configured?(client.event_key),
      has_signing_key: configured?(client.signing_key),
      has_signing_key_fallback: configured?(client.signing_key_fallback),
      mode: mode(client),
      schema_version: @schema_version
    }
  end

  defp authenticated_response(conn, client, framework) do
    case app_id(client) do
      {:ok, app_id} ->
        {200,
         %{
           api_origin: client.api_url,
           app_id: app_id,
           authentication_succeeded: true,
           env: client.env,
           event_api_origin: client.event_url,
           event_key_hash: hash(client.event_key),
           framework: framework,
           function_count: length(client.funcs),
           has_event_key: configured?(client.event_key),
           has_signing_key: configured?(client.signing_key),
           has_signing_key_fallback: configured?(client.signing_key_fallback),
           mode: mode(client),
           schema_version: @schema_version,
           sdk_language: @sdk_language,
           sdk_version: client.sdk_version,
           serve_origin: client.serve_origin,
           serve_path: client.serve_path || conn.request_path,
           signing_key_fallback_hash: Signature.hashed_signing_key(client.signing_key_fallback),
           signing_key_hash: Signature.hashed_signing_key(client.signing_key)
         }}

      {:error, error} ->
        {500, %{error: error}}
    end
  end

  defp app_id(client) do
    case client.id do
      "" -> {:error, "app_id must not be empty"}
      app_id -> {:ok, app_id}
    end
  end

  defp configured?(""), do: false
  defp configured?(_value), do: true

  defp hash(value) do
    if configured?(value) do
      :crypto.hash(:sha256, value)
      |> Base.encode16(case: :lower)
    end
  end

  defp mode(client), do: client.mode |> Atom.to_string()

  defp raw_body(%{private: %{raw_body: body}}) when is_list(body), do: Enum.join(body)
  defp raw_body(_conn), do: ""
end
