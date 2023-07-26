# Step

Use `step` to wrap a block of code and makes it idempotent. This is exactly the
same as `Inngest.Function.run`, except the code within the `step` blocks are
always guaranteed to be executed once. Subsequent calls to the SDK will not
execute and used the previously executed result.

If the code block returns an error or raised an exception, it will be retried.

``` elixir
step "idempotent code block", arg do
  # do
  # something
  # here

  {:ok, %{result: result}}
end
```

Similar to `run`, the result will be passed on to the next execution unit.

See `Inngest.Function.step/3` for more details and how to utilize it.
