# Configuration

There are a couple of configurations you should be aware of before deploying.

- [App Name](#app-name)
- [App Host](#app-host)
- [Env](#env)
- [Event Key](#event-key)
- [Signing Key](#signing-key)
- [Inngest Env](#inngest-env)

### App Name

Default value: `InngestApp`.

The app name to be registered with Inngest.

#### Environment variable

`INNGEST_APP_NAME`

#### Config
``` elixir
config :inngest, app_name: "MyApp"
```

### App Host

Default value: "http://127.0.0.1:4000"

The app host to be used when deployed.

#### Environment variable

`INNGEST_APP_HOST`

#### Config
``` elixir
config :inngest, app_host: "https://myapp.com"
```

### Env

Default value: `nil`

This value determines the environment the app is on, and decides if your app
should connect to the Dev server or Inngest Cloud.

#### Environment variable

`INNGEST_ENV`

#### Config

``` elixir
config :inngest, env: :dev
```

#### NOTE

Make sure to set the value to `:dev` when you're developing locally.
Otherwise it won't connect to the Dev Server and try to connect to Inngest Cloud
instead.

### Event Key

Default value: `nil`

The key used for sending events. It's not required for the Dev Server but required
for Inngest Cloud.

#### Environment variable

`INNGEST_EVENT_KEY`

#### Config

``` elixir
config :inngest, event_key: "key"
```

### Signing Key

Default value: `nil`

The key used for verifying request signatures from the executor to your app, when
triggering function runs.

It's not required for the Dev Server but required for Inngest Cloud.

#### Environment variable

`INNGEST_SIGNING_KEY`

#### Config

``` elixir
config :inngest, signing_key: "key"
```
