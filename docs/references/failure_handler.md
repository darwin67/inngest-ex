# Handling failures

### Failure event

When a function fails, either after exhausting all the retries, or simply
utilizing `Inngest.NonRetriableError`, it will emit an event called
`inngest/function.failed`.

The structure of the event will look something like the following.

```json
{
  "name": "inngest/function.failed",
  "data": {
    "error": {
      "error": "invalid status code: 500",
      "message": "** (ErlangError) Erlang error: \"YOLO!!!\"\n    (inngest 0.1.9) test/support/cases/retriable_error.ex:20: anonymous fn/0 in Inngest.Test.Case.RetriableError.exec/2\n    (inngest 0.1.9) lib/inngest/step_tool.ex:19: Inngest.StepTool.run/3\n    (inngest 0.1.9) test/support/cases/retriable_error.ex:19: Inngest.Test.Case.RetriableError.exec/2\n    (inngest 0.1.9) lib/inngest/router/invoke.ex:90: Inngest.Router.Invoke.invoke/3\n    (inngest 0.1.9) lib/inngest/router/invoke.ex:65: Inngest.Router.Invoke.exec/2\n    (inngest 0.1.9) deps/plug/lib/plug/router.ex:246: anonymous fn/4 in Inngest.Test.PlugRouter.dispatch/2\n    (telemetry 1.2.1) /home/darwin/workspace/ex_inngest/deps/telemetry/src/telemetry.erl:321: :telemetry.span/3\n    (inngest 0.1.9) deps/plug/lib/plug/router.ex:242: Inngest.Test.PlugRouter.dispatch/2\n",
      "name": "Error"
    },
    "event": {
      "data": {},
      "id": "01HGF86PM2CGFPZWF22HSCQFNE",
      "name": "test/plug.retriable",
      "ts": 1701318974082,
      "user": {}
    },
    "function_id": "retriable-fn",
    "run_id": "01HGF86PM90KRQQP27VJZK4BXP"
  },
  "id": "01HGF86VDYZWVBK9K5FT27W6T7",
  "ts": 1701318979006
}
```

See our [documentation](https://www.inngest.com/docs/reference/functions/handling-failures#the-inngest-function-failed-event)
for more details about the `inngest/function.failed` event.

### Handling the failure event

To handle the error event, you can add a method in your `Inngest.Function` module to handle the failure event.

```
defmodule MyApp.Inngest.SomeJob do
  use Inngest.Function
  alias Inngest.{FnOpts, Trigger}

  @func %FnOpts{id: "my-func", name: "some job"}
  @trigger %Trigger{event: "job/foobar"}

  @impl true
  def exec(ctx, input) do
    {:ok, "hello world"}
  end

  # Optional handler to handle failures when the function fails
  # after all retries are exhausted.
  def handler_failure(ctx, %{step: step} = input) do
    # this is just like `exec`, except the event will always be
    # `inngest/function.failed` with the error body
    _ = step.run(ctx, "handle-failure", fn ->
      "handle"
    end)

    {:ok, "error handled"}
  end
end
```
