# Serving the API

Inngest works by serving an HTTP API endpoint which exposes your functions for us to
call on-demand. The first thing you'll need to do is to add and serve the Inngest API
in your project.

## Setting up

The Elixir SDK provides an `inngest` macro, that will setup the required API endpints
to your router. The recommended path is `/api/inngest` since it makes it obvious where
the endpoints are, but you can change it to whatever you see fit.

``` elixir
defmodule MyApp.Router do
  use Inngest.Router, :plug

  inngest("/api/inngest", path: "inngest/**/*.ex")
end
```

Accepted arguments for the `inngest` macros are

- `path`
- `opts`

#### opts

- `func` - the list of modules. e.g. `[MyApp.EventFn, MyApp.CronFn]`
- `path` - the path or paths to the inngest function modules. e.g. `path: "inngest/**/*.ex"`

Among the options, `path` takes precedence.

There are 2 routers available based on what you're using for exposing HTTP endpoints for
your apps:

- `Inngest.Router.Plug`
- `Inngest.Router.Phoenix`
