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
| 3. Environment Variables      | `done`     | [SDK Spec Core Protocol Foundation](../plans/001-sdk-spec-core-protocol-foundation.org)                                             | Required environment variables, mode selection, URL overrides, and configuration precedence are covered by phase 1 tests.                        |
| 4.1. HTTP Headers And Signing | `partial`  | [SDK Spec Core Protocol Foundation](../plans/001-sdk-spec-core-protocol-foundation.org)                                             | SDK/request-version headers, outbound authorization, and signature coverage are implemented. Fallback request behavior continues in phase 2.     |
| 4.3. Sync Requests            | `planned`  | [SDK Spec Serve API](../plans/002-sdk-spec-serve-api.org)                                                                           | Sync request shape, registration payload, registration failure behavior, and deploy metadata forwarding.                                         |
| 4.4. Call Requests            | `planned`  | [SDK Spec Call Requests And Steps](../plans/004-sdk-spec-call-requests-and-steps.org)                                               | Call request parsing, full payload retrieval, context/input shape, and response behavior.                                                        |
| 4.5. Introspection Requests   | `planned`  | [SDK Spec Serve API](../plans/002-sdk-spec-serve-api.org)                                                                           | Authenticated and unauthenticated introspection responses.                                                                                       |
| 5. Steps                      | `planned`  | [SDK Spec Call Requests And Steps](../plans/004-sdk-spec-call-requests-and-steps.org)                                               | Step memoization, opcode shape, targeted execution, and `StepNotFound`.                                                                          |
| 6. Middleware                 | `planned`  | [SDK Spec Developer Ergonomics And Optional Capabilities](../plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org) | Required lifecycle hooks and mutation points.                                                                                                    |
| 7. Modes                      | `done`     | [SDK Spec Core Protocol Foundation](../plans/001-sdk-spec-core-protocol-foundation.org)                                             | Cloud/dev mode selection and precedence are covered by phase 1 tests.                                                                            |
| 8. Connect                    | `deferred` | [SDK Spec Developer Ergonomics And Optional Capabilities](../plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org) | Optional capability; do not advertise until implemented.                                                                                         |
| 9. Streaming                  | `deferred` | [SDK Spec Developer Ergonomics And Optional Capabilities](../plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org) | Optional capability; do not advertise until implemented.                                                                                         |
| 10. Checkpointing             | `deferred` | [SDK Spec Developer Ergonomics And Optional Capabilities](../plans/005-sdk-spec-developer-ergonomics-and-optional-capabilities.org) | Optional capability; do not advertise until implemented.                                                                                         |
| 11. Failure Handlers          | `partial`  | [SDK Spec Call Requests And Steps](../plans/004-sdk-spec-call-requests-and-steps.org)                                               | This SDK currently exposes a failure handler convention, but later plans should verify registration shape and runtime behavior against the spec. |
