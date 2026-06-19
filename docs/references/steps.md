# Steps

Steps split function work into durable units that can be retried and memoized by
Inngest. Step IDs are hashed with SHA-1 before they are reported to the executor.
When the same step ID appears more than once in a function, the SDK appends
`:1`, `:2`, and so on before hashing each repeated occurrence.

## Reporting

| SDK call | Reported opcode | Notes |
|----------|-----------------|-------|
| `step.run/3` | `StepRun` | Used when immediate execution is allowed and the step body runs in the current call request. Includes `data`, even when the result is `nil`. |
| `step.run/4` | `StepRun` | Same as `step.run/3`, with replay options such as `keys: :atoms`. |
| `step.run/3` | `StepPlanned` | Used when `ctx.disable_immediate_execution` prevents running the step body in the current call request. |
| `step.run/3` | `StepError` | Used when an executed step body raises. Includes the serialized `error` payload. |
| targeted `stepId` | `StepNotFound` | Returned when a targeted hashed step ID cannot be found during deterministic traversal. |
| `step.sleep/3`, `step.sleep_until/3` | `Sleep` | Uses `opts.duration` for the duration or ISO timestamp. |
| `step.wait_for_event/3` | `WaitForEvent` | Uses `opts` for event name, timeout, and matching expression. |
| `step.invoke/3` | `InvokeFunction` | Uses `opts.function_id`, `opts.payload`, and optional `opts.timeout`. |
| `step.send_event/3` | `StepRun` | Implemented as a durable run step around event sending. |

## Memoization

Run and invoke-style steps memoize successful values as `%{"data" => value}` and
failed values as `%{"error" => error}`. Successful values are unwrapped before
being returned to user code. Failed memoized steps raise `Inngest.StepError`;
if that error bubbles out of the function, the SDK returns it as a non-retriable
function error.

Sleep steps are memoized as `nil`. Wait-for-event steps are memoized as the
received event payload or `nil` when the wait times out.

Legacy raw run-step values are not supported by the spec-compliant memoization
path. A raw memoized run-step value raises `Inngest.StepError` so payload shape
problems fail clearly.

### Map Keys

Freshly executed `step.run/3` results are returned exactly as user code returns
them. Replayed memoized results come from JSON payloads, so map keys are strings
by default:

```elixir
%{"foo" => "bar"} =
  step.run(ctx, "load", fn ->
    %{foo: "bar"}
  end)
```

Use `step.run/4` with `keys: :atoms` when you need to pattern match on atom keys
after replay:

```elixir
%{foo: "bar"} =
  step.run(ctx, "load", fn ->
    %{foo: "bar"}
  end, keys: :atoms)
```

`keys: :atoms` converts string keys recursively with
`String.to_existing_atom/1`. It will not create new atoms. If a memoized key does
not already exist as an atom, the SDK raises `Inngest.StepError`.

> #### Warning {: .warning}
>
> Atoms are not garbage collected by the Erlang VM. Creating too many atoms can
> exhaust the atom table and crash the VM. The SDK intentionally avoids creating
> atoms from arbitrary memoized JSON keys. Only use `keys: :atoms` for known,
> bounded response shapes whose atom keys already exist in your application.
