.PHONY: dev
dev:
	mix dev

.PHONY: deps
deps:
	mix deps.get

.PHONY: build
build:
	mix compile

.PHONY: unit-test
unit-test:
	MIX_ENV=test UNIT=true mix test

.PHONY: test
test:
	MIX_ENV=test mix test

E2E_ROUTER ?= plug

.PHONY: test-e2e
test-e2e:
	MIX_ENV=test INNGEST_TEST_ROUTER=$(E2E_ROUTER) mix test --only integration --max-cases 1

.PHONY: test-cover
test-cover:
	MIX_ENV=test mix coveralls

.PHONY: fmt
fmt:
	mix fmt:check

.PHONY: lint
lint:
	mix lint

.PHONY: dialyzer
dialyzer:
	mix dialyzer

.PHONY: clean
clean:
	mix deps.clean --unlock --unused

.PHONY: docs
docs:
	mix docs --open

.PHONY: changelog
changelog:
	git cliff -o CHANGELOG.md

.PHONY: bump
bump:
	git cliff --bump -o CHANGELOG.md

.PHONY: inngest-dev
inngest-dev:
	inngest-cli dev -v -u http://127.0.0.1:4000/api/inngest
