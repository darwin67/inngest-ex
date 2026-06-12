# Agent Guide

This file provides guidance to AI coding agents working in this repository.

## Commit Titles

Use conventional commit titles for any commit you create. Keep commit types
aligned with `cliff.toml` and `.github/workflows/convention.yml`.

Prefer these commit types:

- `feat`
- `fix`
- `doc`
- `docs`
- `perf`
- `refactor`
- `style`
- `test`
- `chore`
- `ci`
- `revert`
- `security`

Use standard conventional commit formatting such as
`fix(router): handle missing signature` or
`ci: align release workflow with inngest-rs`.

## Development Commands

- Commit in small logical sections whenever possible so each commit is
  self-reviewable.
- Run `make fmt`, `make lint`, and targeted tests for the area you touch.
- Add tests for behavior changes and bug fixes when practical.
- If you reference a plan while implementing, update its checklist as work
  progresses.

## Testing and Quality

- `make deps` installs Mix dependencies.
- `make build` compiles the project.
- `make fmt` checks formatting.
- `make lint` runs Credo.
- `make dialyzer` runs Dialyzer.
- `make unit-test` runs unit tests and excludes integration tests.
- `make test-e2e` runs integration tests serially against the local Inngest dev server.
- `mix hex.build` verifies the Hex package contents.

## Working Style

- Prefer minimal, targeted changes that preserve existing code style.
- Do not introduce a second commit-title convention.
- Treat generated artifacts such as Hex package tarballs as disposable local build output.
