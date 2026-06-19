# Function configuration

Assign `Inngest.FnOpts` to `@func` to configure how a function is registered and
scheduled. Public Elixir config uses `snake_case` atom keys. The SDK renders the
spec's `camelCase` names only in the registration payload sent to Inngest.

```elixir
defmodule MyApp.InvoiceWorkflow do
  use Inngest.Function

  @func %FnOpts{
    id: "invoice-workflow",
    name: "Invoice Workflow",
    retries: 5,
    debounce: %{
      key: "event.data.account_id",
      period: "10s",
      timeout: "1m"
    },
    priority: %{
      run: "event.data.priority"
    },
    throttle: %{
      key: "event.data.account_id",
      limit: 100,
      period: "1m",
      burst: 10
    },
    singleton: %{
      key: "event.data.invoice_id",
      mode: :skip
    },
    timeouts: %{
      start: "5m",
      finish: "1h"
    },
    concurrency: %{
      limit: 5,
      key: "event.data.account_id",
      scope: "fn"
    },
    idempotency: "event.data.invoice_id"
  }
  @trigger %Trigger{event: "invoice/created"}

  @impl true
  def exec(_ctx, _input), do: {:ok, "done"}
end
```

## Supported options

| Option | Required fields | Optional fields | Registration key | Notes |
|--------|-----------------|-----------------|------------------|-------|
| `retries` | none | integer retry count | `steps.step.retries.attempts` | Defaults to `3`. |
| `debounce` | `period` | `key`, `timeout` | `debounce` | `period` must be a duration up to 7 days. |
| `priority` | none | `run` | `priority` | `run` must be a CEL string when set. |
| `batch_events` | `max_size`, `timeout` | `key` | `batchEvents` | Renders `max_size` as `maxSize`; incompatible with `rate_limit` and `cancel_on`. |
| `rate_limit` | `limit`, `period` | `key` | `rateLimit` | `period` must be from 1 second to 60 seconds. |
| `throttle` | `limit`, `period` | `key`, `burst` | `throttle` | `period` must be a valid duration. |
| `singleton` | `mode` | `key` | `singleton` | `mode` must be `:skip` or `:cancel`; registration renders it as `skip` or `cancel`. |
| `timeouts` | none | `start`, `finish` | `timeouts` | `start` and `finish` must be valid durations when set. |
| `idempotency` | CEL expression string | none | `idempotency` | Prevents duplicate events from triggering a function more than once in 24 hours. |
| `concurrency` | `limit` when using a map | `key`, `scope` | `concurrency` | May also be a number or a list of maps. `scope` must be `fn`, `env`, or `account`. |
| `cancel_on` | `event` | `match`, `if`, `timeout` | `cancel` | May be a map or a list of up to 5 maps. |

## Deferred fields

Checkpoint registration fields are intentionally not implemented. They should not
be emitted until checkpointing runtime behavior is implemented.
