# CHANGELOG

All notable changes to this project will be documented in this file.

## [0.2.0] - 2023-12-04

### Bug Fixes

- Fix: add additional restrictions when using batching (#72)

### Documentation

- Docs: Update docs to prepare for 0.2 release (#62)

### Features

- Feat: add event batching to function configuration
- Feat: Change approach for SDK (#59)
- Feat: Add general retry handling and non retriable error (#63)
- Feat: Add failure handler (#64)
- Feat: debounce support (#65)
- Feat: support batching (#66)
- Feat: rate limit support (#67)
- Feat: concurrency support (#68)
- Feat: idempotency support (#69)
- Feat: cancel on support (#70)
- Feat: priority support (#71)

### Miscellaneous Tasks

- Chore: update ci.yml
- Chore: Clean up (#60)
- Chore: Integration tests (#61)
- Chore: update hashing method for steps (#75)

## [0.1.9] - 2023-08-01

### Bug Fixes

- Fix: make sure to read existing queries (#55)

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

## [0.1.3] - 2023-07-27

### Bug Fixes

- Fix compile errors due to parallel compilation conflicts (#45)

## [0.1.2] - 2023-07-27

## [0.1.1] - 2023-07-27

## [0.1.0] - 2023-07-27

<!-- generated by git-cliff -->
