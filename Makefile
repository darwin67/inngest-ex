.PHONY: dev
dev:
	mix dev

.PHONY: deps
deps:
	mix deps.get

.PHONY: test
test:
	mix test

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
