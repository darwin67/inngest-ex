# Events

See `Inngest.Event` for reference.

## Sending events

Use your first-class client module to send events:

```elixir
MyApp.Inngest.send(%Inngest.Event{
  name: "test/event",
  data: %{hello: "world"}
})
```

You can also send an event to the Dev Server via `curl`:

```bash
curl -X POST 'http://127.0.0.1:8288/e/test' \
  -d '{ "name": "test/event", "data": { "hello": "world" } }'
```

To events to the [Inngest Cloud](https://app.inngest.com):

```bash
curl -X POST 'https://inn.gs/e/:event_key' \
  -d '{ "name": "event-name", "data": {} }'
```
