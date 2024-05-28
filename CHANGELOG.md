# CHANGELOG

All notable changes to this project will be documented in this file.

## [unreleased]

### Features

- Feat: Add support for invoke

### Miscellaneous Tasks

- Chore: replace nix shell with flake (#81)

## [0.2.1] - 2024-05-15

### Bug Fixes

- Fix: Remove test app from `mod` (#78)
- Resolves #77 
- The `Test.Application` is causing apps that included this library to
- Crash on boot, because it's not compiled as part of the release.
- Remove it so it no longer attempts to boot with
- `Inngest.Test.Application`.
- `v0.2.0` is essentially useless at this point, so it should be yanked
- Once this fix is out.
- Update with some minor changes to make it comply to the latest spec.
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

### Miscellaneous Tasks

- Chore: update license to Apache2 (#76)
- Consistency with other SDKs.
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

## [0.2.0] - 2023-12-04

### Bug Fixes

- Fix: add additional restrictions when using batching (#72)
- Cancellation and rate limit can't be used with event batching, so make
- Sure to add those validation as well.
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

### Documentation

- Docs: Update docs to prepare for 0.2 release (#62)
- * Update docs preparing for 0.2 release.
- * Add conventional commit checks for PRs.
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

### Features

- Feat: add event batching to function configuration
- * simplify client config
- * add event batching
- * add config template as comments
- * update docs
- * update docs and references
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: Change approach for SDK (#59)
- Resolves #58
- Change the execution model to match the other SDKs.
- The current attempt is not flexible at all.
- Also update it to follow TS SDK v3 convention.
- - execute function
- - step run
- - step sleep
- - step sleep_until
- - step wait_for_event
- - step send_event
- Feat: Add general retry handling and non retriable error (#63)
- Adds
- * NonRetriableError
- * RetryAfterError
- For better control of retries on failures
- Also refactor invoke to make it easier to reason with.
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: Add failure handler (#64)
- Clean up some useless code and provide a way to call user provided
- Failure handler
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: debounce support (#65)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: support batching (#66)
- Can't add tests now since batching is a cloud only feature at the
- Moment.
- Will need to come back and add it once extracted out into OSS
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: rate limit support (#67)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: concurrency support (#68)
- Resolves #22
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: idempotency support (#69)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: cancel on support (#70)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Feat: priority support (#71)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

### Miscellaneous Tasks

- Chore: update ci.yml
- Chore: Clean up (#60)
- * remove enum file and previous handler
- * remove unused code and comment
- * update comments
- * move test cases into test directory
- * Move dev plug router under supervision tree
- * load inngest dev server as supervised genserver
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Chore: Integration tests (#61)
- - [x] no step function
- - [x] step run function
- - [x] step sleep function
- - [x] step sleep_until function
- - [x] step wait_for_event function
-   - [x] fulfill
-   - [x] timeout
- - [x] step send_event function
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>
- Chore: update hashing method for steps (#75)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

## [0.1.9] - 2023-08-01

### Bug Fixes

- Fix: make sure to read existing queries (#55)
- * fix: make sure parsing works correctly for cache body reader
- * update changelog
- * update version
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

## [0.1.8] - 2023-07-31

### Bug Fixes

- Fix: make certain fields in Event as optional types

## [0.1.7] - 2023-07-31

### Features

- Feat: Allow non map return values
- Feat: Allow no return value with just :ok for step runs

### Miscellaneous Tasks

- Chore: Change type to list of Events

## [0.1.6] - 2023-07-28

### Bug Fixes

- Fix: path takes precedence when passed to `inngest` macro

### Documentation

- Docs: update `inngest` macro docs

## [0.1.5] - 2023-07-28

## [0.1.4] - 2023-07-28

### Miscellaneous Tasks

- Chore: Fix release workflow with proper escapes (#49)
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

## [0.1.3] - 2023-07-27

### Bug Fixes

- Fix compile errors due to parallel compilation conflicts (#45)
- When attempting to compile files from the given path, the lib will fail
- To compile due to compilation race conditions.
- Change module loading to loading into AST, and extracting from there
- Instead.
- ---------
- Co-authored-by: Darwin D Wu <darwin67@users.noreply.github.com>

## [0.1.2] - 2023-07-27

## [0.1.1] - 2023-07-27

## [0.1.0] - 2023-07-27

<!-- generated by git-cliff -->
