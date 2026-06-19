defmodule Inngest.Router.Helper do
  @moduledoc false

  def require_client!(%{client: _client} = params), do: params
  def require_client!(_params), do: raise(ArgumentError, "Inngest router requires :client")

  def client!(%{client: %Inngest.Client{} = client}), do: client

  def client!(%{client: client}) when is_atom(client) do
    if Code.ensure_loaded?(client) and function_exported?(client, :client, 0) do
      client.client()
    else
      raise ArgumentError, "expected :client to expose client/0"
    end
  end

  def client!(_params), do: raise(ArgumentError, "Inngest router requires :client")
end
