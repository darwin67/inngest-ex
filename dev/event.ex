defmodule Inngest.Dev.EventFn2 do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "test-func-v2", name: "test func v2"}
  @trigger %Trigger{event: "test/hello"}

  @impl true
  def exec(%{ctx: ctx, run_id: run_id, step: step} = _args) do
    greet =
      step.run(ctx, "hello", fn ->
        "Hello world"
      end)

    name =
      step.run(ctx, "name", fn ->
        "John Doe"
      end)

    {:ok, "#{greet} #{name}"}
  end
end
