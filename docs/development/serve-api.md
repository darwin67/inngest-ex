# Serving the API

Inngest works by serving an HTTP API endpoint which exposes your functions for us to
call on-demand. The first thing you'll need to do is to add and serve the Inngest API
in your project.

## Setting up

The Elixir SDK provides an `inngest` macro, that will setup the required API endpoints
in your router. The recommended path is `/api/inngest` since it makes it obvious where
the endpoints are, but you can change it to whatever you see fit.

Define a first-class client for the functions your app serves:

```elixir
defmodule MyApp.Inngest do
  use Inngest.Client,
    id: "my-app",
    funcs: [
      MyApp.EventFn,
      MyApp.CronFn
    ]
end
```

### Plug.Router

For a `Plug.Router` app, use the Plug router integration:

```elixir
defmodule MyApp.Router do
  use Inngest.Router, :plug

  inngest("/api/inngest", client: MyApp.Inngest)
end
```

### Phoenix.Router

For a Phoenix app, add the router integration to your Phoenix router and mount
the same client:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Inngest.Router, :phoenix

  scope "/" do
    pipe_through(:api)

    inngest("/api/inngest", client: MyApp.Inngest)
  end
end
```

Signed Inngest requests are verified against the raw request body. Phoenix apps
usually parse request bodies in the endpoint before the router runs, so configure
the endpoint parser with `Inngest.CacheBodyReader`:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    body_reader: {Inngest.CacheBodyReader, :read_body, [[paths: ["/api/inngest"]]]},
    json_decoder: Phoenix.json_library()

  plug MyAppWeb.Router
end
```

The `paths:` option avoids copying unrelated request bodies when `Plug.Parsers`
runs globally in your endpoint. Plug's multipart parser does not use
`:body_reader`; Inngest signed requests are JSON, so the `:json` parser is the
important one for signature verification.

Accepted arguments for the `inngest` macros are

- `client` - the first-class Inngest client module.

There are 2 routers available based on what you're using for exposing HTTP endpoints for
your apps:

- `Inngest.Router.Plug`
- `Inngest.Router.Phoenix`
