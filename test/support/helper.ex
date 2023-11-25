defmodule Inngest.Test.Helper do
  @moduledoc false

  alias Inngest

  @spec send_test_event(binary()) :: binary()
  def send_test_event(event) do
    {:ok,
     %{
       "ids" => [event_id],
       "status" => 200
     }} = Inngest.send(%Inngest.Event{name: event, data: %{}})

    event_id
  end

  @spec send_test_event(binary(), map()) :: binary()
  def send_test_event(event, data) do
    {:ok,
     %{
       "ids" => [event_id],
       "status" => 200
     }} = Inngest.send(%Inngest.Event{name: event, data: data})

    event_id
  end
end
