defmodule Inngest.Test.HTTPClient do
  @moduledoc false

  @behaviour Inngest.HTTPClient

  alias Inngest.HTTPClient.Response

  @handler {__MODULE__, :handler}

  @impl true
  def request(request) do
    case :persistent_term.get(@handler, nil) do
      nil -> raise "no HTTP test handler configured"
      handler -> normalize_response(handler.(request))
    end
  end

  def mock(handler) when is_function(handler, 1) do
    :persistent_term.put(@handler, handler)
    :ok
  end

  def reset! do
    :persistent_term.erase(@handler)
    :ok
  end

  def response(status, body \\ nil, headers \\ []) do
    %Response{status: status, body: body, headers: headers}
  end

  defp normalize_response({:ok, %Response{}} = response), do: response
  defp normalize_response({:error, _error} = error), do: error
  defp normalize_response(%Response{} = response), do: {:ok, response}
end
