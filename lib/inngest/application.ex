defmodule Inngest.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      []
      |> maybe_finch()

    Supervisor.start_link(children, strategy: :one_for_one, name: Inngest.Supervisor)
  end

  @doc false
  @spec finch_children() :: [{module(), Keyword.t()}]
  def finch_children() do
    []
    |> maybe_finch()
  end

  defp maybe_finch(children) do
    if start_finch?() do
      # Finch requires a supervised process. Starting an SDK-owned instance keeps
      # the default HTTP adapter usable without forcing each consumer application
      # to add its own child spec before sending events.
      children ++ [{finch_module!(), finch_options()}]
    else
      children
    end
  end

  defp start_finch? do
    Application.get_env(:inngest, :start_finch, true) &&
      Application.get_env(:inngest, :http_client, Inngest.HTTPClient.Finch) ==
        Inngest.HTTPClient.Finch
  end

  defp finch_options do
    # Pool sizing and other Finch-specific options live under :http_client_opts;
    # SDK-level timeout options are applied per request in the adapter.
    :inngest
    |> Application.get_env(:http_client_opts, [])
    |> Keyword.put_new(:name, Inngest.Finch)
  end

  defp finch_module! do
    if Code.ensure_loaded?(Finch) do
      Finch
    else
      raise """
      Inngest is configured to use the default Finch HTTP adapter, but :finch is not installed.

      Add {:finch, "~> 0.19"} to your dependencies, configure a different :http_client,
      or set config :inngest, start_finch: false when Finch supervision is not needed.
      """
    end
  end
end
