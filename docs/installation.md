# Installation

The Elixir SDK can be downloaded from [Hex][hex]. Add it to your list of dependencies
in `mix.exs`:

``` elixir
# mix.exs
def deps do
  [
    {:inngest, "~> 0.2"}
  ]
end
```

Then run `mix deps.get` to download the package.

## Note

### HTTP client

The Elixir SDK currently uses `Tesla` for handling HTTP requests. While this might
not be ideal for some folks, it's the only option that can swap out the underlying HTTP
libraries while still providing a similar interface.
And it was the easiest to get something out quickly while still providing that portability.

We will be looking into removing this dependency completely in the future with
[`Mint`](https://hexdocs.pm/mint/api-reference.html) or just pure
[`:httpc`](https://www.erlang.org/doc/man/httpc.html).

### Tesla adapters

If you currently have a preferred adapter you want to use, please take a look at their
[Adapters][tesla-adapters] page.

Otherwise, it will utilize the default `Hackney` adapter.

[hex]: https://hex.pm/packages/inngest
[tesla-adapters]: https://hexdocs.pm/tesla/1.7.0/readme.html#adapters
