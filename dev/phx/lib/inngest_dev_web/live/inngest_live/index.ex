defmodule InngestDevWeb.InngestLive.Index do
  use InngestDevWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: false}
  end
end
