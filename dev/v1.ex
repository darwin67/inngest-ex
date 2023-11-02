defmodule Inngest.Dev.EventFn2 do
  @moduledoc false

  use Inngest.V1.Function
  alias Inngest.Function.{Opts, Trigger}

  @func %Opts{name: "test func v2"}
  @trigger %Trigger{event: "test/hello"}

  def run(args) do
    {:ok, "Hello world"}
  end
end
