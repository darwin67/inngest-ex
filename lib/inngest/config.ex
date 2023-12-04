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

  @doc """
  Returns the host of where this inngest function will be served from.
  Defaults to `http://127.0.0.1:4000` for local development.
  """
  @spec app_host() :: binary()
  def app_host() do
    with nil <- System.get_env("INNGEST_APP_HOST"),
         nil <- Application.get_env(:inngest, :app_host) do
      "http://127.0.0.1:4000"
    else
      host -> host
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
  @spec env() :: atom()
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
    with nil <- System.get_env("INNGEST_EVENT_URL"),
         nil <- Application.get_env(:inngest, :event_url) do
      case env() do
        :dev -> @dev_server_url
        _ -> @event_url
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
      case env() do
        :dev -> @dev_server_url
        _ -> @inngest_url
      end
    else
      url -> url
    end
  end

  @spec api_url() :: binary()
  def api_url() do
    case env() do
      :dev -> @dev_server_url
      _ -> @api_url
    end
  end

  @spec register_url() :: binary()
  def register_url() do
    with nil <- System.get_env("INNGEST_REGISTER_URL"),
         nil <- Application.get_env(:inngest, :register_url) do
      case Application.get_env(:inngest, :env, :prod) do
        :dev -> @dev_server_url
        _ -> "https://api.inngest.com"
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

  @spec is_dev() :: boolean()
  def is_dev(), do: env() == :dev

  @spec path_runtime_eval() :: boolean()
  def path_runtime_eval(), do: Application.get_env(:inngest, :path_runtime_eval, false)

  @spec version() :: binary()
  def version(), do: Application.spec(:inngest, :vsn)

  @spec sdk_version() :: binary()
  def sdk_version(), do: "elixir:v#{version()}"

  @spec req_version() :: binary()
  def req_version(), do: "1"
end
