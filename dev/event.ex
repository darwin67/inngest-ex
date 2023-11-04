defmodule Inngest.Dev.EventFn2 do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "test-func-v2", name: "test func v2"}
  @trigger %Trigger{event: "test/hello"}

  @impl true
  def exec(ctx, %{run_id: run_id, step: step} = _args) do
    IO.inspect("First log")

    greet =
      step.run(ctx, "hello", fn ->
        "Hello world"
      end)
      |> IO.inspect()

    IO.inspect("Second log")

    name =
      step.run(ctx, "name", fn ->
        "John Doe"
      end)
      |> IO.inspect()

    {:ok, "#{greet} #{name}"} |> IO.inspect()
  end
end
