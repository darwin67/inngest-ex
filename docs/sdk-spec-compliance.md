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

| Spec Area                     | Status     | Plan                                                                                                                                | Notes                                                                                                                                            |
|-------------------------------|------------|-------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| 3. Environment Variables      | `done`     | [SDK Spec Core Protocol Foundation](plans/001-sdk-spec-core-protocol-foundation.org)                                                | Required environment variables, mode selection, URL overrides, and configuration precedence are covered by phase 1 tests.                        |
| 4.1. HTTP Headers And Signing | `done`     | [SDK Spec Core Protocol Foundation](plans/001-sdk-spec-core-protocol-foundation.org)                                                | SDK/request-version headers, inbound current/fallback verification, outbound fallback retry/sticky behavior, and env-header gating are covered. |
| 4.3. Sync Requests            | `done`     | [SDK Spec Serve API](plans/002-sdk-spec-serve-api.org)                                                                              | Sync request shape, registration payload, registration failure behavior, deploy metadata forwarding, and dev-server smoke coverage are complete. |
| 4.3. Function Configuration   | `done`     | [SDK Spec Function Configuration](plans/003-sdk-spec-function-configuration.org)                                                     | Function-level registration config renders spec keys for debounce, batching, rate limit, throttle, singleton, timeouts, idempotency, concurrency, and cancellation. Checkpoint fields remain deferred until checkpointing is implemented. |
| 4.3. In-Band Sync             | `deferred` | [SDK Spec Serve API](plans/002-sdk-spec-serve-api.org)                                                                              | In-band sync is explicitly deferred until a later plan defines lifecycle and trigger behavior.                                                   |
| 4.4. Call Requests            | `planned`  | [SDK Spec Call Requests And Steps](plans/004-sdk-spec-call-requests-and-steps.org)                                                  | Call request parsing, full payload retrieval, context/input shape, and response behavior.                                                        |
| 4.5. Introspection Requests   | `done`     | [SDK Spec Serve API](plans/002-sdk-spec-serve-api.org)                                                                              | Authenticated and unauthenticated introspection responses are implemented on the shared Plug/Phoenix serve endpoint.                             |
| 5. Steps                      | `planned`  | [SDK Spec Call Requests And Steps](plans/004-sdk-spec-call-requests-and-steps.org)                                                  | Step memoization, opcode shape, targeted execution, and `StepNotFound`.                                                                          |
| 6. Middleware                 | `planned`  | [SDK Spec Developer Ergonomics And Optional Capabilities](plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org)    | Required lifecycle hooks and mutation points.                                                                                                    |
| 7. Modes                      | `done`     | [SDK Spec Core Protocol Foundation](plans/001-sdk-spec-core-protocol-foundation.org)                                                | Cloud/dev mode selection and precedence are covered by phase 1 tests.                                                                            |
| 8. Connect                    | `deferred` | [SDK Spec Developer Ergonomics And Optional Capabilities](plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org)    | Optional capability; do not advertise until implemented.                                                                                         |
| 9. Streaming                  | `deferred` | [SDK Spec Developer Ergonomics And Optional Capabilities](plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org)    | Optional capability; do not advertise until implemented.                                                                                         |
| 10. Checkpointing             | `deferred` | [SDK Spec Developer Ergonomics And Optional Capabilities](plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org)    | Optional capability; do not advertise until implemented.                                                                                         |
| 5. Steps: Advanced Recovery   | `deferred` | [SDK Spec Call Requests And Steps](plans/004-sdk-spec-call-requests-and-steps.org)                                                  | Full out-of-order stack recovery, parallel branch reconstruction, and spec-complete parallel step execution/recovery are deferred beyond the sequential targeted-step recovery in Plan 4. |
| 11. Failure Handlers          | `partial`  | [SDK Spec Call Requests And Steps](plans/004-sdk-spec-call-requests-and-steps.org)                                                  | This SDK currently exposes a failure handler convention, but later plans should verify registration shape and runtime behavior against the spec. |
