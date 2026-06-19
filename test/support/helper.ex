defmodule Inngest.Test.Helper do
  @moduledoc false

  alias Inngest
  @send_retries 50
  @send_retry_interval 100

  @spec send_test_event(binary()) :: binary()
  def send_test_event(event) do
    {:ok,
     %{
       "ids" => [event_id],
       "status" => 200
     }} = send_event(%Inngest.Event{name: event, data: %{}})

    event_id
  end

  @spec send_test_event(binary(), map()) :: binary()
  def send_test_event(event, data) do
    {:ok,
     %{
       "ids" => [event_id],
       "status" => 200
     }} = send_event(%Inngest.Event{name: event, data: data})

    event_id
  end

  defp send_event(event, retries \\ @send_retries)

  defp send_event(event, 0), do: Inngest.Test.Client.send(event)

  defp send_event(event, retries) do
    case Inngest.Test.Client.send(event) do
      {:error, _} ->
        Process.sleep(@send_retry_interval)
        send_event(event, retries - 1)

      result ->
        result
    end
  end
end
