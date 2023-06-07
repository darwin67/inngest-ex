defmodule Inngest do
  alias Inngest.{Client, Event}

  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC ! -->")
             |> Enum.fetch!(1)

  @doc """
  Send one or a batch of events to Inngest
  """
  @spec send(Event.t() | [Event.t()]) :: :ok | :error
  def send(payload), do: Client.send(payload)
end
