# Installation

The Elixir SDK can be downloaded from [Hex][hex]. Add it to your list of dependencies
in `mix.exs`:

``` elixir
# mix.exs
def deps do
  [
    {:inngest, "~> 0.2"},
    {:finch, "~> 0.19"}
  ]
end
```

Then run `mix deps.get` to download the package.

## HTTP client

The SDK uses a small `Inngest.HTTPClient` behaviour for outbound HTTP. The
default adapter is `Inngest.HTTPClient.Finch`. Finch is an optional dependency
of the SDK, so applications using the default adapter should include it directly
and add a Finch process to their supervision tree:

```elixir
children = [
  {Finch, name: Inngest.Finch}
]
```

To use a different Finch process name, configure the adapter options on your
client:

```elixir
children = [
  {Finch, name: MyApp.InngestFinch}
]

defmodule MyApp.Inngest do
  use Inngest.Client,
    id: "my-app",
    funcs: [MyApp.Function],
    http_client_opts: [name: MyApp.InngestFinch]
end
```

Hackney is also available as a supported non-default adapter. Add it to your
application dependencies before selecting it:

```elixir
def deps do
  [
    {:inngest, "~> 0.2"},
    {:hackney, "~> 1.25"}
  ]
end
```

```elixir
defmodule MyApp.Inngest do
  use Inngest.Client,
    id: "my-app",
    funcs: [MyApp.Function],
    http_client: Inngest.HTTPClient.Hackney
end
```

Hackney does not require Finch supervision. It can also be configured globally:

```elixir
config :inngest, http_client: Inngest.HTTPClient.Hackney
```

For custom HTTP clients, implement the behaviour and configure it on the
first-class client:

```elixir
defmodule MyApp.InngestHTTPClient do
  @behaviour Inngest.HTTPClient

  @impl true
  def request(%Inngest.HTTPClient.Request{} = request) do
    # Execute request.url with your preferred HTTP library and return:
    {:ok,
     %Inngest.HTTPClient.Response{
       status: 200,
       headers: [],
       body: %{}
     }}
  end
end

defmodule MyApp.Inngest do
  use Inngest.Client,
    id: "my-app",
    funcs: [MyApp.Function],
    http_client: MyApp.InngestHTTPClient
end
```

Application config is still supported as a compatibility/test fallback:

```elixir
config :inngest, http_client: MyApp.InngestHTTPClient
```

If you previously configured Tesla adapters, move that configuration into a
custom `Inngest.HTTPClient` implementation or switch to the built-in Finch or
Hackney adapters.

[hex]: https://hex.pm/packages/inngest
