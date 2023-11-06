defmodule Inngest.Test.Case.NoStepFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "no-step-fn", name: "No Step Function"}
  @trigger %Trigger{event: "test/no-step"}

  @impl true
  def exec(_, _args) do
    {:ok, "hello world"}
  end
end
