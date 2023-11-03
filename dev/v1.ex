defmodule Inngest.Dev.EventFn2 do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "test-func-v2", name: "test func v2"}
  @trigger %Trigger{event: "test/hello"}

  @impl true
  def run(args) do
    {:ok, "Hello world"}
  end
end
