# Events

See `Inngest.Event` for reference.

## Sending events

Use `Inngest.Client.send/1` or you can send it to Dev server via `curl`:

```bash
curl -X POST 'http://127.0.0.1:8288/e/test' \
  -d '{ "name": "test/event", "data": { "hello": "world" } }'
```

To events to the [Inngest Cloud](https://app.inngest.com):

```bash
curl -X POST 'https://inn.gs/e/:event_key' \
  -d '{ "name": "event-name", "data": {} }'
```
