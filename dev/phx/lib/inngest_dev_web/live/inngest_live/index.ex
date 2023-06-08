defmodule InngestDevWeb.InngestLive.Index do
  use InngestDevWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    %{
      "handlers" => handlers,
      "functions" => functions
    } = Inngest.Client.dev_info()

    sdk_versions =
      handlers
      |> Enum.map(fn h -> h |> Map.get("sdk", %{}) |> Map.get("sdk") end)
      |> Enum.uniq()

    socket =
      socket
      |> assign(
        sdk_versions: sdk_versions,
        functions: functions |> Enum.map(&Inngest.Function.from/1) |> IO.inspect()
      )

    {:ok, socket, layout: false}
  end
end
