defmodule Inngest.Config do
  @moduledoc """
  Configuration settings for Inngest
  """
  @event_url "https://inn.gs"
  @dev_url "http://127.0.0.1:8288"

  def event_base_url do
    if Mix.env() == :dev do
      @dev_url
    else
      @event_url
    end
  end

  def event_key do
    case System.get_env("INNGEST_EVENT_KEY") do
      nil ->
        if Mix.env() == :dev do
          "test"
        else
          nil
        end

      key ->
        key
    end
  end

  @spec version() :: binary()
  def version(), do: Application.spec(:inngest, :vsn)

  @spec sdk_version() :: binary()
  def sdk_version(), do: "elixir:v#{version()}"
end
