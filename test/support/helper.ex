defmodule Inngest.Test.Helper do
  @moduledoc false

  alias Inngest

  def send_test_event(event) do
    {:ok,
     %{
       "ids" => [event_id],
       "status" => 200
     }} = Inngest.send(%Inngest.Event{name: event, data: %{}})

    event_id
  end
end
