defmodule Inngest.Config do
  @moduledoc false

  # Configuration settings for Inngest. Order of configuration to be read:
  # 1. Environment variables
  # 2. Application configs
  # 3. Default values

  @event_url "https://inn.gs"
  @inngest_url "https://app.inngest.com"
  @api_url "https://api.inngest.com"
  @dev_server_url "http://127.0.0.1:8288"

  @type mode() :: :cloud | :dev

  @doc """
  Returns the host of where this inngest function will be served from.
  Defaults to `http://127.0.0.1:4000` for local development.
  """
  @spec app_host() :: binary()
  def app_host() do
    with nil <- System.get_env("INNGEST_SERVE_ORIGIN"),
         nil <- Application.get_env(:inngest, :serve_origin),
         nil <- Application.get_env(:inngest, :app_host) do
      "http://127.0.0.1:4000"
    else
      host -> host
    end
  end

  @spec serve_path() :: binary() | nil
  def serve_path() do
    with nil <- System.get_env("INNGEST_SERVE_PATH"),
         nil <- Application.get_env(:inngest, :serve_path) do
      nil
    else
      path -> path
    end
  end

  @doc """
  Returns the App name to be registered with the inngestion functions.
  Defaults to `InngestApp`.
  """
  @spec app_name() :: binary()
  def app_name() do
    with nil <- System.get_env("INNGEST_APP_NAME"),
         nil <- Application.get_env(:inngest, :app_name) do
      "InngestApp"
    else
      app_name -> app_name
    end
  end

  @doc """
  Returns the current inngest environment.
  """
  @spec env() :: atom() | binary() | nil
  def env() do
    case System.get_env("INNGEST_ENV") do
      nil ->
        Application.get_env(:inngest, :env)

      env ->
        env
    end
  end

  @doc """
  Returns the base url for accessing the event API.
  This is where the events are sent to.
  """
  @spec event_url() :: binary()
  def event_url() do
    with nil <- System.get_env("INNGEST_EVENT_API_BASE_URL"),
         nil <- System.get_env("INNGEST_BASE_URL"),
         nil <- System.get_env("INNGEST_EVENT_URL"),
         nil <- Application.get_env(:inngest, :event_url) do
      case mode() do
        :dev -> dev_server_url()
        :cloud -> @event_url
      end
    else
      url -> url
    end
  end

  @doc """
  returns the base url for Inngest.
  """
  @spec inngest_url() :: binary()
  def inngest_url() do
    with nil <- System.get_env("INNGEST_URL"),
         nil <- Application.get_env(:inngest, :inngest_url) do
      case mode() do
        :dev -> dev_server_url()
        :cloud -> @inngest_url
      end
    else
      url -> url
    end
  end

  @spec api_url() :: binary()
  def api_url() do
    with nil <- System.get_env("INNGEST_API_BASE_URL"),
         nil <- System.get_env("INNGEST_BASE_URL"),
         nil <- Application.get_env(:inngest, :api_url) do
      case mode() do
        :dev -> dev_server_url()
        :cloud -> @api_url
      end
    else
      url -> url
    end
  end

  @spec register_url() :: binary()
  def register_url() do
    with nil <- System.get_env("INNGEST_API_BASE_URL"),
         nil <- System.get_env("INNGEST_BASE_URL"),
         nil <- System.get_env("INNGEST_REGISTER_URL"),
         nil <- Application.get_env(:inngest, :register_url) do
      case mode() do
        :dev -> dev_server_url()
        :cloud -> @api_url
      end
    else
      url -> url
    end
  end

  @doc """
  Returns the set event_key.
  """
  @spec event_key() :: binary()
  def event_key() do
    with nil <- System.get_env("INNGEST_EVENT_KEY"),
         nil <- Application.get_env(:inngest, :event_key) do
      "test"
    else
      key -> key
    end
  end

  @doc """
  Returns the set registration key.
  """
  @spec signing_key() :: binary()
  def signing_key() do
    with nil <- System.get_env("INNGEST_SIGNING_KEY"),
         nil <- Application.get_env(:inngest, :signing_key) do
      ""
    else
      key -> key
    end
  end

  @spec signing_key_fallback() :: binary()
  def signing_key_fallback() do
    with nil <- System.get_env("INNGEST_SIGNING_KEY_FALLBACK"),
         nil <- Application.get_env(:inngest, :signing_key_fallback) do
      ""
    else
      key -> key
    end
  end

  @spec mode() :: mode()
  def mode() do
    case dev_env_mode() do
      :unset ->
        case Application.get_env(:inngest, :env) do
          :dev -> :dev
          "dev" -> :dev
          _ -> :cloud
        end

      mode ->
        mode
    end
  end

  @spec dev?() :: boolean()
  def dev?(), do: mode() == :dev

  @spec path_runtime_eval() :: boolean()
  def path_runtime_eval(), do: Application.get_env(:inngest, :path_runtime_eval, false)

  @spec version() :: binary()
  def version(), do: Application.spec(:inngest, :vsn)

  @spec sdk_version() :: binary()
  def sdk_version(), do: "inngest-ex:v#{version()}"

  @spec req_version() :: binary()
  def req_version(), do: "2"

  defp dev_env_mode() do
    case System.get_env("INNGEST_DEV") do
      nil -> :unset
      value when value in ["", "0", "false", "FALSE", "False"] -> :cloud
      _ -> :dev
    end
  end

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
end
