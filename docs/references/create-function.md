# Create functions

Creating an Inngest function is as easy as using `Inngest.Function`. It creates
the necessary attributes and handlers it needs to work with Inngest.

``` elixir
defmodule MyApp.Inngest.SomeJob do
  use Inngest.Function,
    name: "some job",
    event_name: "job/foobar"
end
```

- [Configuration](#configuration)
- [Trigger](#trigger)
- [Handler](#handler)

## Configuration

The `Inngest.Function` macro accepts the following options.

#### id - string (optional)

A unique identifier for your function to override the default name.
Also known in technical terms, a `slug`.

#### name - string (required)

A unique name for your function. This will be used to create a unique
slug id by default if `id` is not provided.


## Trigger

A trigger is exactlyi what the name says. It's the thing that triggers a function
to run. One of the following is required, and they're mutually exclusive.

#### event_name - string

The name of the event that will trigger this event to run.
We recommend it to name it with a prefix so it's a easier pattern to identify
what it's for.

e.g. `auth/signup.email.send`

#### cron - string

A [unix-cron](https://crontab.guru/) compatible schedule string.

Optional timezone prefix, e.g. `TZ=Europe/Paris 0 12 * * 5`.

## Handlers

The handlers are your code that runs whenever the trigger occurs.

``` elixir
defmodule MyApp.Inngest.SomeJob do
  use Inngest.Function,
    name: "some job",
    event_name: "job/foobar"

  # This will run when an event `job/foobar` is received
  run "do something", %{event: event, data: data} do
    # do
    # some
    # stuff

    {:ok, %{result: result}} # returns a map as a result
  end
end
```

Unlike some other SDKs, the Elixir SDK follows the pattern `ExUnit` is using.
Essentially providing a DSL that wraps your logic, making them deterministic.

All handlers can be repeated, and they will be executed in the order they're
declared:

- [`run`](run.html) - Run code non-deterministically, executing every time the function is triggered
- [`step`](step.html) - Run code deterministically, and individually retryable.
- [`sleep`](sleep.html) - Sleep for a given amount of time or until a given time.
- [`wait_for_event`](wait-for-event.html) - Pause a function's execution until another event is received.
