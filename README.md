<p align="center">
  <a href="https://www.inngest.com">
    <img alt="Inngest logo" src="https://user-images.githubusercontent.com/306177/191580717-1f563f4c-31e3-4aa0-848c-5ddc97808a9a.png" width="350" />
  </a>
</p>

<p align="center">
  Effortless queues, background jobs, and workflows. <br />
  Easily develop workflows in your current codebase, without any new infrastructure.
</p>

<!-- MDOC ! -->

<p align="center">
  <a href="https://github.com/darwin67/ex-inngest/actions/workflows/ci.yml">
    <img src="https://github.com/darwin67/ex-inngest/actions/workflows/ci.yml/badge.svg" />
  </a>
  <a href="https://discord.gg/EuesV2ZSnX">
    <img src="https://img.shields.io/discord/842170679536517141?label=discord" />
  </a>
  <a href="https://twitter.com/inngest">
    <img src="https://img.shields.io/twitter/follow/inngest?style=social" />
  </a>
</p>


Inngest is an event driven platform that helps you build reliable background jobs and
workflows effortlessly.

Using our SDK, easily add retries, queues, sleeps, cron schedules, fan-out jobs, and
reliable steps functions into your existing projects. It's deployable to any platform,
without any infrastructure. We do the hard stuff so you can focus on building what you
want.
And, everything is locally testable via our Dev server.

## Installation

The Elixir SDK can be downloaded from Hex. Add it to your list of dependencies in `mix.exs`

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

See the guides for more details regarding use cases and how each macros can be used.

### Dev server

![Dev server screenshot](https://github.com/darwin67/ex_inngest/assets/5746693/d8b80b54-5238-4c4b-bf76-6e15bee590a7)

Inngest provides a dev server you can run locally to aid with local development. Start
the Dev server with:

```sh
npx inngest-cli@latest dev
```

This will download the latest version available and you should be able to access it
via `http://localhost:8288`.

If you prefer to download the CLI locally:

```sh
npm i -g inngest-cli
# or
npm i -g inngest-cli@<version>
```

then:

``` sh
inngest-cli dev
```

#### Auto discovery

The Dev server will try to auto discover apps and functions via `http://localhost:3000/api/inngest`
by default. However, apps like Phoenix typically runs on port `4000`. You can provide the auto
discovery URL when starting the Dev server:

``` sh
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest
```

This will tell the Dev server to look at `http://127.0.0.1:4000/api/inngest` to discover and
register apps/functions.

### Events

As you might guess, `Events` are the fundamentals of an event driven system. Inngest starts and
ends with events. An event is the trigger for functions to start, resume and can also hold the
data for functions to operate on.

An Inngest `Event` looks like this:

``` json
{
  "id": "",
  "name": "event/awesome",
  "data": { "hello": "world" },
  "user" { "external_id": 10000 },
  "ts": 1690156151,
  "v": "2023.04.14.1"
}
```

##### id - string (optional)

The `id` field in an event payload is used for deduplication. Setting this field will make
sure that only one of the events (the first one) with a similar `id` is processed.

##### name - string (required)

The name of the event. We recommend using lowercase dot notation for names, prepending
`<prefixes>/` with a slash for organization.

##### data - map (required)

Any data to associate with the event. Will be serialized as JSON.

##### user - map (optional)

Any relevant user identifying data or attributes associated with the event. **This data is
encrypted at rest**. Use the `external_id` as the identifier. A common example is the `user_id`
in your system.

##### ts - integer (optional)

A timestamp integer representing the unix time (in milliseconds) at which the event occurred.
Defaults to the time the Inngest receives the event if not provided.

##### v - string (optional)

A version identifier for a particular event payload. e.g. `2023-04-14.1`

#### Sending events

Use `Inngest.Client.send/1` or you can send it via `curl`:

``` sh
curl -X POST 'http://127.0.0.1:8288/e/test' -d '{ "name": "test/event", "data": { "hello": "world" } }'
```

<!-- MDOC ! -->

[inngest]: https://www.inngest.com
[hex]: https://hex.pm/packages/inngest
[hexdocs]: https://hexdocs.pm/inngest
