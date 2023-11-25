defmodule Inngest.Test.Case.DebounceFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{
    id: "debounce-fn",
    name: "Debounce Function",
    debounce: %{
      period: "5s"
    }
  }
  @trigger %Trigger{event: "test/plug.debounce"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _ = step.run(ctx, "debounce", fn -> ":+1" end)

    {:ok, "debounced"}
  end
end

defmodule Inngest.Test.Case.DebounceWithKeyFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{
    id: "debounce-fn-with-key",
    name: "Debounce Function (key)",
    debounce: %{
      period: "5s",
      key: "event.data.foobar"
    }
  }
  @trigger %Trigger{event: "test/plug.debounce-with-key"}

  @impl true
  def exec(ctx, %{step: step} = _args) do
    _ = step.run(ctx, "debounce", fn -> ":+1" end)

    {:ok, "debounced"}
  end
end
