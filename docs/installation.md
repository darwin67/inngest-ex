# Installation

The Elixir SDK can be downloaded from [Hex][hex]. Add it to your list of dependencies
in `mix.exs`:

``` elixir
# mix.exs
def deps do
  [
    {:inngest, "~> 0.1"}
  ]
end
```

Then run `mix deps.get` to download the package.

## Note

### HTTP client

The Elixir SDK currently uses `Tesla` for handling HTTP requests. While this might
not be ideal for some folks, it's the only option that can swap out the underlying HTTP
libraries while still providing a similar interface.

Until there's either a standard `Protocol` defined for handling HTTP calls or HTTP libraries
actually being standardized, or a better way of abstracting the HTTP interfaces away, `Tesla`
will likely be here to stay.

### Tesla adapters

If you currently have a preferred adapter you want to use, please take a look at their
[Adapters][tesla-adapters] page.

Otherwise, it will utilize the default `Hackney` adapter.

[hex]: https://hex.pm/packages/inngest
[tesla-adapters]: https://hexdocs.pm/tesla/1.7.0/readme.html#adapters
