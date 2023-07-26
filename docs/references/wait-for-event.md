# Wait for events

Use `wait_for_event` to wait for a particular event to be received before continuing.
It returns the accepted event object or `nil` if the event is not received within
the timeout.

``` elixir
wait_for_event "auth/signup.email.confirmed", arg do
  match = "user.id"
  [timeout: "1d", if: "event.#{match} == async.#{match}"]
end
# or in a shorter version
wait_for_event "auth/signup.email.confirmed", do: [timeout: "1d", match: "user.id"]
```

The event name will be used as the key for storing the return event.

See `Inngest.Function.wait_for_event/3` for more details and how to utilize it.
