defmodule Inngest.Client do
  @moduledoc """
  Module representing an Inngest client (subject to change).
  """
  alias Inngest.{Config, Event, Headers, Middleware, Signature}
  alias Inngest.HTTPClient.{Request, Response}

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
          middleware: [Middleware.normalized_entry()],
          http_client: module(),
          http_client_opts: Keyword.t(),
          http_pool_timeout: timeout(),
          http_receive_timeout: timeout(),
          http_request_timeout: timeout(),
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
    middleware: [],
    http_client: Inngest.HTTPClient.Finch,
    http_client_opts: [],
    http_pool_timeout: 5_000,
    http_receive_timeout: 10_000,
    http_request_timeout: 15_000,
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

      @spec send(Inngest.Event.t() | list(Inngest.Event.t())) :: {:ok, map()} | {:error, binary()}
      def send(payload) do
        Inngest.Client.send(client(), payload)
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
      middleware: client_middleware(opts),
      http_client: client_http_client(opts),
      http_client_opts: client_http_client_opts(opts),
      http_pool_timeout: client_http_timeout(opts, :http_pool_timeout, 5_000),
      http_receive_timeout: client_http_timeout(opts, :http_receive_timeout, 10_000),
      http_request_timeout: client_http_timeout(opts, :http_request_timeout, 15_000),
      sdk_version: Config.sdk_version(),
      req_version: Config.req_version()
    }
    |> register_middleware()
  end

  @doc false
  @spec serve_url(t(), binary()) :: binary()
  def serve_url(%__MODULE__{} = client, request_path) do
    path = client.serve_path || request_path

    client.serve_origin
    |> String.trim_trailing("/")
    |> Kernel.<>(normalize_path(path))
  end

  @doc """
  Send one or a batch of events to Inngest
  """
  @type send_result() :: {:ok, map()} | {:error, binary()}

  @spec send(t(), Event.t() | list(Event.t())) :: send_result()
  def send(payload, opts \\ [])

  def send(%__MODULE__{} = client, payload) do
    send(client, payload, [])
  end

  @spec send(Event.t() | list(Event.t()), Keyword.t()) :: send_result()
  def send(payload, opts) when not is_struct(payload, __MODULE__) do
    event_key = Config.event_key()
    middleware = opts |> Keyword.get(:middleware, []) |> Middleware.normalize()
    context = Keyword.get(opts, :context, %{})
    payload = Middleware.run_transform_send_event(middleware, List.wrap(payload), context)

    Middleware.run_wrap_send_event(
      middleware,
      %{events: payload, context: context, function: Map.get(context, :function)},
      fn ->
        :event
        |> do_request(:post, "/e/#{event_key}", payload, opts)
        |> decode_send_http_response()
      end
    )
  end

  @spec send(t(), Event.t() | list(Event.t()), Keyword.t()) :: send_result()
  def send(%__MODULE__{} = client, payload, opts) do
    middleware = opts |> Keyword.get(:middleware, client.middleware) |> Middleware.normalize()
    context = Keyword.get(opts, :context, %{client: client})
    payload = Middleware.run_transform_send_event(middleware, List.wrap(payload), context)

    Middleware.run_wrap_send_event(
      middleware,
      %{events: payload, context: context, function: Map.get(context, :function)},
      fn ->
        client
        |> do_request(:event, :post, "/e/#{client.event_key}", payload, opts)
        |> decode_send_http_response()
      end
    )
  end

  # Retrieves the registration information from the Dev server.
  @doc false
  def dev_info() do
    case do_request(:inngest, :get, "/dev", nil, []) do
      {:ok, %Response{status: 200, body: body}} ->
        {:ok, body}

      _ ->
        {:error, "failed to retrieve dev server info"}
    end
  end

  @doc false
  @spec headers(t(), atom(), Keyword.t()) :: [{binary(), binary()}]
  def headers(%__MODULE__{} = client, type, opts) when is_atom(type) do
    client
    |> default_headers(type, opts)
    |> merge_headers(Keyword.get(opts, :headers, []))
  end

  @spec headers(atom(), Keyword.t()) :: [{binary(), binary()}]
  def headers(type, opts \\ []) do
    type
    |> default_headers(opts)
    |> merge_headers(Keyword.get(opts, :headers, []))
  end

  @doc false
  @spec get(atom(), binary(), Keyword.t()) :: {:ok, Response.t()} | {:error, term()}
  def get(%__MODULE__{} = client, type, path, opts),
    do: request(client, type, :get, path, nil, opts)

  def get(type, path, opts \\ []), do: request(type, :get, path, nil, opts)

  @doc false
  @spec post(atom(), binary(), term(), Keyword.t()) :: {:ok, Response.t()} | {:error, term()}
  def post(%__MODULE__{} = client, type, path, payload, opts),
    do: request(client, type, :post, path, payload, opts)

  def post(type, path, payload, opts \\ []), do: request(type, :post, path, payload, opts)

  @doc false
  @spec reset_signing_key_fallback!() :: :ok
  def reset_signing_key_fallback!() do
    :persistent_term.erase(@fallback_signing_key)
    :ok
  end

  # Inngest may return send responses as parsed JSON or text/plain JSON.
  defp decode_send_http_response({:ok, %Response{status: status, body: resp}})
       when status in 200..299,
       do: decode_send_response(resp)

  defp decode_send_http_response({:ok, %Response{status: 400}}),
    do: {:error, "invalid event data"}

  defp decode_send_http_response({:ok, %Response{status: 401}}),
    do: {:error, "unknown ingest key"}

  defp decode_send_http_response({:ok, %Response{status: 403}}),
    do: {:error, "this ingest key is not authorized to send this event"}

  defp decode_send_http_response(_), do: {:error, "unknown error"}

  defp decode_send_response(resp) when is_binary(resp), do: Jason.decode(resp)
  defp decode_send_response(resp), do: {:ok, resp}

  defp request(%__MODULE__{} = client, type, method, path, payload, opts)
       when type in [:api, :register] do
    case client_initial_signing_key(client) do
      {:ok, :primary, key} ->
        resp =
          do_request(client, type, method, path, payload, Keyword.put(opts, :signing_key, key))

        maybe_retry_with_client_fallback(resp, client, type, method, path, payload, opts)

      {:ok, :fallback, key} ->
        do_request(client, type, method, path, payload, Keyword.put(opts, :signing_key, key))

      :error ->
        if client.mode == :dev do
          do_request(client, type, method, path, payload, opts)
        else
          {:error, "missing signing key"}
        end
    end
  end

  defp request(%__MODULE__{} = client, type, method, path, payload, opts) do
    do_request(client, type, method, path, payload, opts)
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

  defp do_request(type, method, path, payload, opts) do
    adapter = http_client(opts)
    request = request_struct(type, method, path, payload, opts)

    adapter.request(request)
  end

  defp do_request(%__MODULE__{} = client, type, method, path, payload, opts) do
    adapter = http_client(client, opts)
    request = request_struct(client, type, method, path, payload, opts)

    adapter.request(request)
  end

  defp maybe_retry_with_client_fallback(
         {:ok, %Response{status: status}} = resp,
         client,
         type,
         method,
         path,
         payload,
         opts
       )
       when status in [401, 403] do
    case usable_signing_key(client.signing_key_fallback) do
      {:ok, fallback} ->
        do_request(client, type, method, path, payload, Keyword.put(opts, :signing_key, fallback))

      :error ->
        resp
    end
  end

  defp maybe_retry_with_client_fallback(resp, _client, _type, _method, _path, _payload, _opts),
    do: resp

  defp maybe_retry_with_fallback(
         {:ok, %Response{status: status}} = resp,
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

  defp mark_fallback_on_success({:ok, %Response{status: status}} = resp)
       when status in 200..299 do
    :persistent_term.put(@fallback_signing_key, true)
    resp
  end

  defp mark_fallback_on_success(resp), do: resp

  defp request_struct(type, method, path, payload, opts) do
    base_url = base_url(type)
    query = Keyword.get(opts, :query)

    # Preserve both structured request parts and final URL. Adapters execute
    # with url; tests and custom adapters can assert against base_url/path/query.
    %Request{
      method: method,
      base_url: base_url,
      path: path,
      query: query,
      url: build_url(base_url, path, query),
      headers: headers(type, opts),
      body: payload,
      pool_timeout: http_timeout(opts, :http_pool_timeout, 5_000),
      receive_timeout: http_timeout(opts, :http_receive_timeout, 10_000),
      request_timeout: http_timeout(opts, :http_request_timeout, 15_000),
      adapter_opts: http_client_opts(opts)
    }
  end

  defp request_struct(%__MODULE__{} = client, type, method, path, payload, opts) do
    base_url = client_base_url(client, type)
    query = Keyword.get(opts, :query)

    # Client-owned requests carry client-specific headers, adapter, and timeout
    # settings while keeping the same transport contract as global requests.
    %Request{
      method: method,
      base_url: base_url,
      path: path,
      query: query,
      url: build_url(base_url, path, query),
      headers: headers(client, type, opts),
      body: payload,
      pool_timeout: http_timeout(client, opts, :http_pool_timeout),
      receive_timeout: http_timeout(client, opts, :http_receive_timeout),
      request_timeout: http_timeout(client, opts, :http_request_timeout),
      adapter_opts: http_client_opts(client, opts)
    }
  end

  defp http_client(%__MODULE__{} = client, opts) do
    Keyword.get(opts, :http_client) || client.http_client || http_client(opts)
  end

  defp http_client(opts) do
    Keyword.get(opts, :http_client) ||
      Application.get_env(:inngest, :http_client, Inngest.HTTPClient.Finch)
  end

  defp http_client_opts(%__MODULE__{} = client, opts) do
    Keyword.get(opts, :http_client_opts, client.http_client_opts)
  end

  defp http_client_opts(opts) do
    Keyword.get(opts, :http_client_opts, Application.get_env(:inngest, :http_client_opts, []))
  end

  defp http_timeout(%__MODULE__{} = client, opts, key) do
    Keyword.get(opts, key) || Map.fetch!(client, key)
  end

  defp http_timeout(opts, key, default) do
    Keyword.get(opts, key) || Application.get_env(:inngest, key, default)
  end

  defp base_url(:event), do: Config.event_url()
  defp base_url(:register), do: Config.register_url()
  defp base_url(:api), do: Config.api_url()
  defp base_url(_type), do: Config.inngest_url()

  defp build_url(base_url, path, nil), do: build_url(base_url, path, [])

  defp build_url(base_url, path, query) do
    url =
      base_url
      |> String.trim_trailing("/")
      |> Kernel.<>(normalize_path(path))

    case URI.encode_query(query) do
      "" -> url
      encoded_query -> url <> query_separator(url) <> encoded_query
    end
  end

  defp query_separator(url), do: if(String.contains?(url, "?"), do: "&", else: "?")

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

  defp default_headers(%__MODULE__{} = client, type, opts) do
    [
      {Headers.sdk_version(), client.sdk_version},
      {Headers.req_version(), client.req_version}
    ]
    |> maybe_client_env_header(client)
    |> maybe_client_auth_header(client, type, opts)
  end

  defp maybe_client_env_header(headers, %{env: nil}), do: headers

  defp maybe_client_env_header(headers, %{env: env}),
    do: headers ++ [{Headers.env(), to_string(env)}]

  defp maybe_client_auth_header(headers, client, type, opts) when type in [:api, :register] do
    signing_key = Keyword.get(opts, :signing_key, client.signing_key)

    case Signature.hashed_signing_key(signing_key) do
      nil -> headers
      key -> headers ++ [{"authorization", "Bearer " <> key}]
    end
  end

  defp maybe_client_auth_header(headers, _client, _type, _opts), do: headers

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

  defp client_initial_signing_key(client) do
    client.signing_key
    |> usable_signing_key()
    |> tag_signing_key(:primary)
    |> client_fallback_to_fallback(client)
  end

  defp client_fallback_to_fallback({:ok, :primary, _key} = result, _client), do: result

  defp client_fallback_to_fallback(:error, client) do
    client.signing_key_fallback
    |> usable_signing_key()
    |> tag_signing_key(:fallback)
  end

  defp client_base_url(%__MODULE__{} = client, :event), do: client.event_url
  defp client_base_url(%__MODULE__{} = client, :register), do: client.register_url
  defp client_base_url(%__MODULE__{} = client, :api), do: client.api_url
  defp client_base_url(%__MODULE__{} = client, _type), do: client.inngest_url

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

  defp client_middleware(opts) do
    opts
    |> Keyword.get(:middleware, Application.get_env(:inngest, :middleware, []))
    |> Middleware.normalize()
  end

  defp client_http_client(opts) do
    Keyword.get(opts, :http_client) ||
      Application.get_env(:inngest, :http_client, Inngest.HTTPClient.Finch)
  end

  defp client_http_client_opts(opts) do
    Keyword.get(opts, :http_client_opts, Application.get_env(:inngest, :http_client_opts, []))
  end

  defp client_http_timeout(opts, key, default) do
    Keyword.get(opts, key) || Application.get_env(:inngest, key, default)
  end

  defp register_middleware(%__MODULE__{} = client) do
    Middleware.run_on_register(client.middleware, %{client: client, function: nil})

    Enum.each(client.funcs, fn func ->
      func
      |> Middleware.function_middleware()
      |> Middleware.run_on_register(%{client: client, function: func})
    end)

    client
  end

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

  defp normalize_path(path) when is_binary(path) do
    if String.starts_with?(path, "/"), do: path, else: "/" <> path
  end

  defp normalize_path(_), do: ""
end
