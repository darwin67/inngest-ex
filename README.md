[![CI](https://github.com/darwin67/ex-inngest/actions/workflows/ci.yml/badge.svg)](https://github.com/darwin67/ex-inngest/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/inngest.svg)](https://hex.pm/packages/inngest)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/inngest/)

<!-- MDOC ! -->

### Experimental - non official, use at your own risk

Elixir SDK for **[Inngest](https://www.inngest.com)**

## Installation

The Elixir SDK can be downloaded from [Hex](https://hex.pm/packages/inngest). Add it
to your list of dependencies in `mix.exs`

``` elixir
# mix.exs
def deps do
  [
    {:inngest, "~> 0.1"}
  ]
end
```

### Example

This is a basic example of what an Inngest function will look like.

A Module can be turned into an Inngest function easily by using the `Inngest.Function`
macro.

``` elixir
defmodule MyApp.AwesomeFunction do
  use Inngest.Function,
    name: "awesome function", # The name of the function
    event: "func/awesome"     # The event this function will react to

  # Declare a "run" macro that runs contains the business logic
  run "hello world" do
    {:ok, %{result: "hello world"}}
  end
end
```

The Elixir SDK follows `ExUnit`'s pattern of accumulative macros, where each block
is a self contained piece of logic.

You can declare multiple blocks of `run` or other available macros, and the function
will execute the code in the order it is declared.

#### Advanced

Here's a slightly more complicated version, which should provide you an idea what is
capable with Inngest.

``` elixir
defmodule MyApp.AwesomeFunction do
  use Inngest.Function,
    name: "awesome function", # The name of the function
    event: "func/awesome"     # The event this function will react to

  # An Inngest function will automatically retry when it fails

  # "run" is a normal unit execution. It is not memorized and will be
  # executed every time the function gets re-invoked.
  #
  # The return "data" from each execution block will be accumulated
  # and passed on to the next execution
  run "1st run" do
    {:ok, %{run: "do something"}}
  end

  # "step" is a unit execution where the return value will be memorized.
  # An already executed "step" will not be executed again when re-invoked
  # and will use the previously returned value
  #
  # e.g. The previous `%{run: "do something"}` can be extracted out via
  # pattern matching, just like how you do it in `ExUnit`
  step "1st step", %{data: %{run: output}} do
    {:ok, %{hey: output}}
  end

  # "sleep" will pause the execution for the declared amount of duration.
  sleep "2s"

  step "2nd step" do
    {:ok, %{yo: "lo"}}
  end

  # "sleep" can also sleep until a valid datetime string
  sleep "until July 31 2023 - 8pm", do: "2023-07-18T07:31:00Z"

  # "wait_for_event" will pause the function execution until the declared
  # event is received
  wait_for_event "test/wait", do: [timeout: "1d", match: "data.yo"]

  step "result", %{data: data} do
    {:ok, %{result: data}}
  end
end
```

See the **[guides](https://hexdocs.pm/inngest)** for more details regarding use cases and how each macros can be used.

<!-- MDOC ! -->

[inngest]: https://www.inngest.com
