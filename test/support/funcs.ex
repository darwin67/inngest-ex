defmodule Inngest.TestCronFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "test-cron", name: "Awesome Cron Func"}
  @trigger %Trigger{cron: "TZ=America/Los_Angeles * * * * *"}

  @impl true
  def exec(_ctx, _args) do
    {:ok, "cron"}
  end
end
