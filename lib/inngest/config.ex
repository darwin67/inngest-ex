defmodule Inngest.Config do
  @moduledoc """
  Configuration settings for Inngest

  Order of configuration to be read
  1. Environment variables
  2. Application configs
  3. Default values
  """
  @event_url "https://inn.gs"
  @inngest_url "https://app.inngest.com"
  @dev_server_url "http://127.0.0.1:8288"

  @spec event_url() :: binary()
  def event_url() do
    with nil <- System.get_env("INNGEST_EVENT_URL"),
         nil <- Application.get_env(:inngest, :event_url) do
      case Application.get_env(:inngest, :env, :prod) do
        :dev -> @dev_server_url
        _ -> @event_url
      end
    else
      url -> url
    end
  end

  @spec inngest_url() :: binary()
  def inngest_url() do
    with nil <- System.get_env("INNGEST_URL"),
         nil <- Application.get_env(:inngest, :inngest_url) do
      case Application.get_env(:inngest, :env, :prod) do
        :dev -> @dev_server_url
        _ -> @inngest_url
      end
    else
      url -> url
    end
  end

  @spec event_key() :: binary()
  def event_key() do
    with nil <- System.get_env("INNGEST_EVENT_KEY"),
         nil <- Application.get_env(:inngest, :event_key) do
      "test"
    else
      key -> key
    end
  end

  @spec signing_key() :: binary()
  def signing_key() do
    with nil <- System.get_env("INNGEST_SIGNING_KEY"),
         nil <- Application.get_env(:inngest, :signing_key) do
      ""
    else
      key -> key
    end
  end

  @spec version() :: binary()
  def version(), do: Application.spec(:inngest, :vsn)

  @spec sdk_version() :: binary()
  def sdk_version(), do: "elixir:v#{version()}"
end
