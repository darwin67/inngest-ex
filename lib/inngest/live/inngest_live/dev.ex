defmodule Inngest.Live.InngestLive.Dev do
  use Phoenix.LiveView
  import Inngest.Live.InngestLive.Component

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        sdk_version: Inngest.Config.sdk_version(),
        functions: [],
        registered: false,
        connected: false,
        rendered: false
      )

    socket = if connected?(socket), do: load_data(socket), else: socket

    {:ok, socket, layout: false}
  end

  defp load_data(socket) do
    case Inngest.Client.dev_info() do
      {:ok, %{"handlers" => nil, "functions" => nil} = _body} ->
        socket |> assign(registered: false, connected: true)

      {:ok, %{"handlers" => _handlers, "functions" => functions}} ->
        socket
        |> assign(
          functions: functions |> Enum.map(&Inngest.Function.from/1),
          registered: true,
          connected: true
        )

      {:error, _} ->
        socket |> assign(registered: false, connected: false)
    end
    |> assign(rendered: true)
  end
end
