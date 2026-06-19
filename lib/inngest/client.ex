defmodule Inngest.Client do
  @moduledoc """
  Module representing an Inngest client (subject to change).
  """
  alias Inngest.{Config, Event, Headers, Signature}

  @fallback_signing_key {__MODULE__, :fallback_signing_key}
  @event_url "https://inn.gs"
  @inngest_url "https://app.inngest.com"
  @api_url "https://api.inngest.com"
  @dev_server_url "http://127.0.0.1:8288"

  @type mode() :: :cloud | :dev

  @type t() :: %__MODULE__{
          id: binary(),
          funcs: [module()],
          mode: mode(),
          api_url: binary(),
          event_url: binary(),
          register_url: binary(),
          inngest_url: binary(),
          serve_origin: binary(),
          serve_path: binary() | nil,
          event_key: binary(),
          signing_key: binary(),
          signing_key_fallback: binary(),
          env: binary() | nil,
          sdk_version: binary(),
          req_version: binary()
        }

  defstruct [
    :id,
    :env,
    :serve_path,
    funcs: [],
    mode: :cloud,
    api_url: @api_url,
    event_url: @event_url,
    register_url: @api_url,
    inngest_url: @inngest_url,
    serve_origin: "http://127.0.0.1:4000",
    event_key: "test",
    signing_key: "",
    signing_key_fallback: "",
    sdk_version: nil,
    req_version: nil
  ]

  defmacro __using__(opts) do
    quote location: :keep do
      @inngest_client_opts unquote(opts)

      @spec client() :: Inngest.Client.t()
      def client() do
        Inngest.Client.new(@inngest_client_opts)
      end
    end
  end

  @doc """
  Builds a runtime Inngest client from explicit client options and environment.
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    mode = client_mode(opts)

    %__MODULE__{
      id: client_id!(opts),
      funcs: Keyword.get(opts, :funcs, []),
      mode: mode,
      api_url: client_api_url(opts, mode),
      event_url: client_event_url(opts, mode),
      register_url: client_register_url(opts, mode),
      inngest_url: client_inngest_url(opts, mode),
      serve_origin: client_serve_origin(opts),
      serve_path: client_serve_path(opts),
      event_key: client_event_key(opts),
      signing_key: client_signing_key(opts),
      signing_key_fallback: client_signing_key_fallback(opts),
      env: client_env(opts),
      sdk_version: Config.sdk_version(),
      req_version: Config.req_version()
    }
  end

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | list(Event.t()), Keyword.t()) :: {:ok, map()} | {:error, binary()}
  def send(payload, opts \\ []) do
    event_key = Config.event_key()
    client = httpclient(:event, opts)

    case Tesla.post(client, "/e/#{event_key}", payload) do
      {:ok, %Tesla.Env{status: 200, body: resp}} ->
        # NOTE: because resp headers currently says text/plain
        # so http client won't automatically decode it as json
        if is_binary(resp) do
          Jason.decode(resp)
        else
          {:ok, resp}
        end

      {:ok, %Tesla.Env{status: 400}} ->
        {:error, "invalid event data"}

      {:ok, %Tesla.Env{status: 401}} ->
        {:error, "unknown ingest key"}

      {:ok, %Tesla.Env{status: 403}} ->
        {:error, "this ingest key is not authorized to send this event"}

      _ ->
        {:error, "unknown error"}
    end
  end

  # Retrieves the registration information from the Dev server.
  @doc false
  def dev_info() do
    client = httpclient(:inngest)

    case Tesla.get(client, "/dev") do
      {:ok, %Tesla.Env{status: 200, body: body} = _resp} ->
        {:ok, body}

      _ ->
        {:error, "failed to retrieve dev server info"}
    end
  end

  # Returns an HTTP client for making requests against Inngest.
  @doc false
  @spec httpclient(atom(), Keyword.t()) :: Tesla.Client.t()
  def httpclient(type, opts \\ [])

  def httpclient(:event, opts), do: client(Config.event_url(), :event, opts)
  def httpclient(:register, opts), do: client(Config.register_url(), :register, opts)
  def httpclient(:api, opts), do: client(Config.api_url(), :api, opts)
  def httpclient(type, opts), do: client(Config.inngest_url(), type, opts)

  @doc false
  @spec headers(atom(), Keyword.t()) :: [{binary(), binary()}]
  def headers(type, opts \\ []) do
    type
    |> default_headers(opts)
    |> merge_headers(Keyword.get(opts, :headers, []))
  end

  @doc false
  @spec get(atom(), binary(), Keyword.t()) :: {:ok, Tesla.Env.t()} | {:error, term()}
  def get(type, path, opts \\ []), do: request(type, :get, path, nil, opts)

  @doc false
  @spec post(atom(), binary(), term(), Keyword.t()) :: {:ok, Tesla.Env.t()} | {:error, term()}
  def post(type, path, payload, opts \\ []), do: request(type, :post, path, payload, opts)

  @doc false
  @spec reset_signing_key_fallback!() :: :ok
  def reset_signing_key_fallback!() do
    :persistent_term.erase(@fallback_signing_key)
    :ok
  end

  defp client(base_url, type, opts) do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON
    ]

    middleware = middleware ++ [{Tesla.Middleware.Headers, headers(type, opts)}]

    Tesla.client(middleware)
  end

  defp request(type, method, path, payload, opts) when type in [:api, :register] do
    case initial_signing_key() do
      {:ok, key_kind, key} ->
        resp = do_request(type, method, path, payload, Keyword.put(opts, :signing_key, key))

        maybe_retry_with_fallback(resp, key_kind, type, method, path, payload, opts)

      :error ->
        request_without_signing_key(type, method, path, payload, opts)
    end
  end

  defp request(type, method, path, payload, opts) do
    do_request(type, method, path, payload, opts)
  end

  defp do_request(type, :get, path, _payload, opts) do
    type
    |> httpclient(opts)
    |> Tesla.get(path)
  end

  defp do_request(type, :post, path, payload, opts) do
    type
    |> httpclient(opts)
    |> Tesla.post(path, payload)
  end

  defp maybe_retry_with_fallback(
         {:ok, %Tesla.Env{status: status}} = resp,
         :primary,
         type,
         method,
         path,
         payload,
         opts
       )
       when status in [401, 403] do
    case usable_signing_key(Config.signing_key_fallback()) do
      {:ok, fallback} ->
        type
        |> do_request(method, path, payload, Keyword.put(opts, :signing_key, fallback))
        |> mark_fallback_on_success()

      :error ->
        resp
    end
  end

  defp maybe_retry_with_fallback(resp, _key_kind, _type, _method, _path, _payload, _opts),
    do: resp

  defp request_without_signing_key(type, method, path, payload, opts) do
    if Config.dev?() do
      do_request(type, method, path, payload, opts)
    else
      {:error, "missing signing key"}
    end
  end

  defp mark_fallback_on_success({:ok, %Tesla.Env{status: status}} = resp)
       when status in 200..299 do
    :persistent_term.put(@fallback_signing_key, true)
    resp
  end

  defp mark_fallback_on_success(resp), do: resp

  defp default_headers(type, opts) do
    [
      {Headers.sdk_version(), Config.sdk_version()},
      {Headers.req_version(), Config.req_version()}
    ]
    |> maybe_env_header()
    |> maybe_auth_header(type, opts)
  end

  defp maybe_env_header(headers) do
    case Config.inngest_env() do
      nil -> headers
      env -> headers ++ [{Headers.env(), env}]
    end
  end

  defp maybe_auth_header(headers, type, opts) when type in [:api, :register] do
    signing_key = Keyword.get_lazy(opts, :signing_key, &active_signing_key/0)

    case Signature.hashed_signing_key(signing_key) do
      nil -> headers
      key -> headers ++ [{"authorization", "Bearer " <> key}]
    end
  end

  defp maybe_auth_header(headers, _type, _opts), do: headers

  defp initial_signing_key() do
    if fallback_signing_key?() do
      Config.signing_key_fallback()
      |> usable_signing_key()
      |> tag_signing_key(:fallback)
      |> fallback_to_primary()
    else
      Config.signing_key()
      |> usable_signing_key()
      |> tag_signing_key(:primary)
      |> fallback_to_fallback()
    end
  end

  defp active_signing_key() do
    case initial_signing_key() do
      {:ok, _key_kind, key} -> key
      :error -> Config.signing_key()
    end
  end

  defp fallback_to_primary({:ok, :fallback, _key} = result), do: result

  defp fallback_to_primary(:error) do
    Config.signing_key()
    |> usable_signing_key()
    |> tag_signing_key(:primary)
  end

  defp fallback_to_fallback({:ok, :primary, _key} = result), do: result

  defp fallback_to_fallback(:error) do
    Config.signing_key_fallback()
    |> usable_signing_key()
    |> tag_signing_key(:fallback)
  end

  defp tag_signing_key({:ok, key}, key_kind), do: {:ok, key_kind, key}
  defp tag_signing_key(:error, _key_kind), do: :error

  defp usable_signing_key(key) do
    case Signature.hashed_signing_key(key) do
      nil -> :error
      _hashed -> {:ok, key}
    end
  end

  defp fallback_signing_key?() do
    :persistent_term.get(@fallback_signing_key, false)
  end

  defp client_id!(opts) do
    case Keyword.get(opts, :id) do
      id when is_binary(id) and id != "" -> id
      _ -> raise ArgumentError, "Inngest client requires a non-empty :id"
    end
  end

  defp client_mode(opts) do
    opts
    |> Keyword.get(:mode)
    |> normalize_mode()
    |> case do
      :unset -> env_mode()
      mode -> mode
    end
  end

  defp normalize_mode(mode) when mode in [:cloud, "cloud"], do: :cloud
  defp normalize_mode(mode) when mode in [:dev, "dev"], do: :dev
  defp normalize_mode(nil), do: :unset

  defp normalize_mode(mode) do
    raise ArgumentError, "invalid Inngest client mode: #{inspect(mode)}"
  end

  defp env_mode() do
    case System.get_env("INNGEST_DEV") do
      nil -> :cloud
      value when value in ["", "0", "false", "FALSE", "False"] -> :cloud
      _ -> :dev
    end
  end

  defp client_api_url(opts, mode) do
    explicit_url(opts, [:api_url, :api_base_url]) ||
      System.get_env("INNGEST_API_BASE_URL") ||
      System.get_env("INNGEST_BASE_URL") ||
      default_url(mode, @api_url)
  end

  defp client_event_url(opts, mode) do
    explicit_url(opts, [:event_url, :event_api_url, :event_api_base_url]) ||
      System.get_env("INNGEST_EVENT_API_BASE_URL") ||
      System.get_env("INNGEST_BASE_URL") ||
      System.get_env("INNGEST_EVENT_URL") ||
      default_url(mode, @event_url)
  end

  defp client_register_url(opts, mode) do
    explicit_url(opts, [:register_url]) ||
      System.get_env("INNGEST_REGISTER_URL") ||
      System.get_env("INNGEST_API_BASE_URL") ||
      System.get_env("INNGEST_BASE_URL") ||
      default_url(mode, @api_url)
  end

  defp client_inngest_url(opts, mode) do
    explicit_url(opts, [:inngest_url, :base_url]) ||
      System.get_env("INNGEST_URL") ||
      default_url(mode, @inngest_url)
  end

  defp client_serve_origin(opts) do
    explicit_url(opts, [:serve_origin]) ||
      System.get_env("INNGEST_SERVE_ORIGIN") ||
      "http://127.0.0.1:4000"
  end

  defp client_serve_path(opts),
    do: Keyword.get(opts, :serve_path) || System.get_env("INNGEST_SERVE_PATH")

  defp client_event_key(opts),
    do: Keyword.get(opts, :event_key) || System.get_env("INNGEST_EVENT_KEY") || "test"

  defp client_signing_key(opts),
    do: Keyword.get(opts, :signing_key) || System.get_env("INNGEST_SIGNING_KEY") || ""

  defp client_signing_key_fallback(opts),
    do:
      Keyword.get(opts, :signing_key_fallback) ||
        System.get_env("INNGEST_SIGNING_KEY_FALLBACK") ||
        ""

  defp client_env(opts), do: Keyword.get(opts, :env) || System.get_env("INNGEST_ENV")

  defp explicit_url(opts, keys) do
    keys
    |> Enum.map(&Keyword.get(opts, &1))
    |> Enum.find(&(&1 not in [nil, ""]))
  end

  defp default_url(:dev, _cloud_url), do: dev_server_url()
  defp default_url(:cloud, cloud_url), do: cloud_url

  defp dev_server_url() do
    case System.get_env("INNGEST_DEV") do
      url when is_binary(url) ->
        uri = URI.parse(url)

        if uri.scheme in ["http", "https"] && is_binary(uri.host) do
          url
        else
          @dev_server_url
        end

      _ ->
        @dev_server_url
    end
  end

  defp merge_headers(headers, overrides) do
    override_names = MapSet.new(overrides, fn {name, _value} -> normalize_header(name) end)

    headers =
      Enum.reject(headers, fn {name, _value} -> normalize_header(name) in override_names end)

    headers ++ overrides
  end

  defp normalize_header(name) when is_atom(name),
    do: name |> Atom.to_string() |> String.downcase()

  defp normalize_header(name), do: name |> to_string() |> String.downcase()
end
