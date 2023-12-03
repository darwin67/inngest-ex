defmodule Inngest.Test.Case.RateLimitFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{
    id: "ratelimit-fn",
    name: "RateLimit Function",
    rate_limit: %{
      limit: 2,
      period: "5s"
    }
  }
  @trigger %Trigger{event: "test/plug.ratelimit"}

  @impl true
  def exec(_ctx, _args) do
    {:ok, "Rate Limited"}
  end
end
