# Run

`Inngest.Function.run/3` is a block wrapping normal, non-deterministic code.
Meaning whenever, Inngest asks the SDK to execute a function, the code block
wrapped within `run` will always run.

Hence making it non deterministic, since each execution can yield a different
result.

``` elixir
run "non deterministic logic", arg do
  # do
  # something
  # here

  {:ok, %{result: result}}
end
```

This is best for things that do not need idempotency. The result here will be
passed on to the next execution unit.

See `Inngest.Function.run/3` for more details.
