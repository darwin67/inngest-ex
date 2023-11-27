defmodule Inngest.Test.Case.IdempotentFn do
  @moduledoc false

  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{
    id: "idempotent-fn",
    name: "Idempotent Function",
    idempotency: "event.data.foobar"
  }
  @trigger %Trigger{event: "test/plug.idempotency"}

  @impl true
  def exec(_ctx, _args) do
    {:ok, "Done"}
  end
end
