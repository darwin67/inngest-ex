# Configuration

Configure an Inngest app by defining a first-class client module:

```elixir
defmodule MyApp.Inngest do
  use Inngest.Client,
    id: "my-app",
    funcs: [
      MyApp.Functions.SendEmail,
      MyApp.Functions.SyncUser
    ]
end
```

Pass that client to your Plug or Phoenix router:

```elixir
inngest("/api/inngest", client: MyApp.Inngest)
```

## Client Options

| Option                 | Description                                      |
|------------------------|--------------------------------------------------|
| `id`                   | Required app identifier used for registration.   |
| `funcs`                | Function modules served by this client.          |
| `mode`                 | `:cloud` or `:dev`.                              |
| `env`                  | Inngest environment header value.                |
| `event_key`            | Event key used for sending events.               |
| `signing_key`          | Signing key used for request/API authentication. |
| `signing_key_fallback` | Fallback signing key.                            |
| `api_url`              | REST API origin.                                 |
| `event_url`            | Event API origin.                                |
| `register_url`         | Registration API origin.                         |
| `inngest_url`          | Dev server metadata origin.                      |
| `serve_origin`         | Public origin serving the Inngest endpoint.      |
| `serve_path`           | Public path serving the Inngest endpoint.        |

Explicit client options take precedence over SDK environment variables. Environment
variables fill missing client options, and defaults apply after both are absent.

## Environment Variables

Use environment variables for secrets and deploy-specific values:

| Variable                       | Used For                            |
|--------------------------------|-------------------------------------|
| `INNGEST_EVENT_KEY`            | Event sending key.                  |
| `INNGEST_SIGNING_KEY`          | Primary signing key.                |
| `INNGEST_SIGNING_KEY_FALLBACK` | Fallback signing key.               |
| `INNGEST_ENV`                  | Inngest environment header value.   |
| `INNGEST_DEV`                  | Enables dev mode or dev origin.     |
| `INNGEST_API_BASE_URL`         | REST API origin.                    |
| `INNGEST_EVENT_API_BASE_URL`   | Event API origin.                   |
| `INNGEST_BASE_URL`             | Shared API/event origin fallback.   |
| `INNGEST_SERVE_ORIGIN`         | Public origin for served functions. |
| `INNGEST_SERVE_PATH`           | Public path for served functions.   |

Avoid committing `event_key` or signing keys into client modules. Prefer runtime
environment variables for those values.
