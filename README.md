## Notice

This is the README for `main` branch, which is for pre `0.2.0` release.

<!-- MDOC ! -->

<div align="center">
  <a href="https://www.inngest.com"><img src="https://user-images.githubusercontent.com/306177/191580717-1f563f4c-31e3-4aa0-848c-5ddc97808a9a.png" width="300" /></a>
  <br/>
  <br/>
  <p>
    A durable event-driven workflow engine SDK for Elixir.<br />
    Read the <a href="https://www.inngest.com/docs?ref=github-inngest-elixir-readme">documentation</a> and get started in minutes.
  </p>
  <p>
    <a href="https://github.com/darwin67/ex-inngest/actions/workflows/ci.yml"><img src="https://github.com/darwin67/ex-inngest/actions/workflows/ci.yml/badge.svg"></a>
    <a href="https://codecov.io/gh/inngest/ex_inngest" ><img src="https://codecov.io/gh/inngest/ex_inngest/graph/badge.svg?token=t7231eD24T"/></a>
    <a href="https://hex.pm/packages/inngest"><img src="https://img.shields.io/hexpm/v/inngest.svg" /></a>
    <a href="https://hexdocs.pm/inngest/"><img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" /></a>
    <br/>
    <a href="https://www.inngest.com/discord"><img src="https://img.shields.io/discord/842170679536517141?label=discord" /></a>
    <a href="https://twitter.com/inngest"><img src="https://img.shields.io/twitter/follow/inngest?style=social" /></a>
  </p>
</div>

# [Inngest](https://www.inngest.com) Elixir SDK

Inngest's Elixir SDK allows you to create event-driven, durable workflows in your
existing API — without new infrastructure.

It's useful if you want to build reliable software without worrying about queues,
events, subscribers, workers, or other complex primitives such as concurrency,
parallelism, event batching, or distributed debounce. These are all built in.

## Installation

The Elixir SDK can be downloaded from [Hex](https://hex.pm/packages/inngest). Add it
to your list of dependencies in `mix.exs`

``` elixir
# mix.exs
def deps do
  [
    {:inngest, git: "https://github.com/inngest/ex_inngest.git", branch: "main"}
  ]
end
```

### Example

This is a basic example of what an Inngest function will look like.

A Module can be turned into an Inngest function easily by using the `Inngest.Function`
macro.

``` elixir
defmodule MyApp.AwesomeFunction do
  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "awesome-fn", name: "Awesome Function"} # The id and name of the function
  @trigger %Trigger{event: "func/awesome"} # The event this function will react to

  @impl true
  def exec(_ctx, _input) do
    IO.inspect("Do something")

    {:ok, "hello world"}
  end
end
```

And just like that, you have an Inngest function that will react to an event called `func/awesome`.
`Inngest.Function.exec/2` will then be called by the SDK to run and execute the logic.

#### Advanced

The above example will be no different from other background processing libraries, so let's take a
look at a more complicated version. Which should provide you an idea what is capable with Inngest.

``` elixir
defmodule MyApp.AwesomeFunction do
  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "awesome-fn", name: "Awesome Function"} # The id and name of the function
  @trigger %Trigger{event: "func/awesome"} # The event this function will react to

  @impl true
  def exec(ctx, %{step: step} = input) do
    IO.inspect("Starting function...")

    %{greet: greet} =
      # A return value wrapped in a `step` are memorized, meaning
      # it's guaranteed to be idempotent.
      # if it fails, it'll be retried.
      step.run(ctx, "step1", fn ->
        %{greet: "hello"}
      end)

    # Sleeping will pause the execution from running, and function
    # will be reinvoked when time is up.
    step.sleep(ctx, "wait-a-little", "10s")

    %{name: name} =
      step.run(ctx, "retrieve-user", fn ->
        # retrieve user from here
        %{name: user_name}
      end)

    # There are times you want to wait for something to happen before
    # continue on the workflow. `wait_for_event` allows exactly that.
    evt = step.wait_for_event("wait-for-registration-complete", %{
      event: "user/register.completed",
      timeout: "1h"
    })

    # You might want to trigger some other workflow, sending an event
    # will trigger the functions that are registered against the `event`.
    step.send_event("completed-work", %{
      name: "func/awesome.completed",
      data: %{name: name}
    })

    {:ok, %{greetings: "#{greet} #{name}", registered: is_nil(evt)}}
  end
end
```

See the **[guides](https://hexdocs.pm/inngest)** for more details regarding use cases and how each macros can be used.

<!-- MDOC ! -->

[inngest]: https://www.inngest.com
