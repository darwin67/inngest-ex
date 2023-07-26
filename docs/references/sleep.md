# Sleep

Use `sleep` to pause the execution of your function for a duration or until a
specific time.

``` elixir
# duration
sleep "2s"
# or
sleep "sleep until 2023-10-25", arg do
  # do something to caculate time

  # return the specified time that it should sleep until
  "2023-07-18T07:31:00Z"
end
```

Currently only expect a string format of date time.

See

- `Inngest.Function.sleep/1`
- `Inngest.Function.sleep/3`

for more details and how to utilize it.
