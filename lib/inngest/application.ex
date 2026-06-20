defmodule Inngest.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Finch requires a supervised process. Starting an SDK-owned instance keeps
    # the default HTTP adapter usable without forcing each consumer application
    # to add its own child spec before sending events.
    children = [
      {Finch, finch_options()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Inngest.Supervisor)
  end

  defp finch_options do
    # Pool sizing and other Finch-specific options live under :http_client_opts;
    # SDK-level timeout options are applied per request in the adapter.
    :inngest
    |> Application.get_env(:http_client_opts, [])
    |> Keyword.put_new(:name, Inngest.Finch)
  end
end
