# SDK Spec Compliance Checklist

Canonical spec: https://github.com/inngest/inngest/blob/main/docs/SDK_SPEC.md

## Status Legend

| Status     | Meaning                                                     |
|------------|-------------------------------------------------------------|
| `planned`  | Covered by a local implementation plan but not implemented. |
| `partial`  | Implemented in part, or implemented with known spec gaps.   |
| `done`     | Implemented and covered by local tests.                     |
| `deferred` | Optional or explicitly out of scope for the current plans.  |

## Compliance Areas

| Spec Area                     | Status     | Notes                                                                                                                                                                                                                                     |
|-------------------------------|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 3. Environment Variables      | `done`     | Required environment variables, mode selection, URL overrides, and configuration precedence are covered by tests.                                                                                                                         |
| 4.1. HTTP Headers And Signing | `done`     | SDK/request-version headers, inbound current/fallback verification, outbound fallback retry/sticky behavior, and env-header gating are covered.                                                                                           |
| 4.3. Sync Requests            | `done`     | Sync request shape, registration payload, registration failure behavior, deploy metadata forwarding, and dev-server smoke coverage are complete.                                                                                          |
| 4.3. Function Configuration   | `done`     | Function-level registration config renders spec keys for debounce, batching, rate limit, throttle, singleton, timeouts, idempotency, concurrency, and cancellation. Checkpoint fields remain deferred until checkpointing is implemented. |
| 4.3. In-Band Sync             | `deferred` | In-band sync is explicitly deferred until a later plan defines lifecycle and trigger behavior.                                                                                                                                            |
| 4.4. Call Requests            | `done`     | Call request parsing around `ctx.use_api`, full payload retrieval, context/input shape, fetch failure behavior, and targeted `stepId` response behavior are covered.                                                                      |
| 4.5. Introspection Requests   | `done`     | Authenticated and unauthenticated introspection responses are implemented on the shared Plug/Phoenix serve endpoint.                                                                                                                      |
| 5. Steps                      | `done`     | Step memoization, opcode shape, targeted execution, `StepError`, and `StepNotFound` are covered for sequential execution.                                                                                                                 |
| 6. Middleware                 | `done`     | Behaviour-module middleware follows the current TypeScript SDK hook model with `on_register`, `transform_*`, `wrap_*`, and `on_*` lifecycle hooks across client/function registration, event sending, request handling, runs, and steps. |
| 7. Modes                      | `done`     | Cloud/dev mode selection and precedence are covered by tests.                                                                                                                                                                             |
| 8. Connect                    | `deferred` | Optional capability; do not advertise until implemented.                                                                                                                                                                                  |
| 9. Streaming                  | `deferred` | Optional capability; do not advertise until implemented.                                                                                                                                                                                  |
| 10. Checkpointing             | `deferred` | Optional capability; do not advertise until implemented.                                                                                                                                                                                  |
| 5. Steps: Advanced Recovery   | `deferred` | Full out-of-order stack recovery, parallel branch reconstruction, and spec-complete parallel step execution/recovery are deferred beyond the sequential targeted-step recovery already implemented.                                       |
| 5.3.6. AI Gateway             | `deferred` | Optional step capability; do not advertise until implemented.                                                                                                                                                                             |
| 5.3.7. Gateway HTTP Fetch     | `deferred` | Optional step capability; do not advertise until implemented.                                                                                                                                                                             |
| 11. Failure Handlers          | `partial`  | This SDK currently exposes a failure handler convention, but later work should verify registration shape and runtime behavior against the spec.                                                                                           |

## Deferred Decisions

| Decision                        | Status     | Notes                                                                                                                                                   |
|---------------------------------|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| Middleware client struct config | `done`     | Middleware attaches to client modules/runtime structs, and function-level middleware composes after client middleware.                                 |
| Connect                         | `deferred` | Optional capability; do not advertise until implemented.                                                                                                |
| Streaming                       | `deferred` | Optional capability; do not advertise until implemented.                                                                                                |
| Checkpointing                   | `deferred` | Optional capability; checkpoint registration fields remain deferred until checkpoint runtime behavior is implemented.                                   |
| AI Gateway                      | `deferred` | Optional step capability; do not advertise until implemented.                                                                                           |
| Gateway HTTP Fetch              | `deferred` | Optional step capability; do not advertise until implemented.                                                                                           |
| In-band sync                    | `deferred` | Deferred until a later plan defines lifecycle and trigger behavior.                                                                                     |
| Trust probe                     | `deferred` | Do not advertise through introspection until a separate trust probe feature exists. Signed introspection alone is not sufficient.                       |
