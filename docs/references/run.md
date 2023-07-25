# Run

`Inngest.Function.run/3` is a block wrapping normal, non-deterministic code.
Meaning whenever, Inngest asks the SDK to execute a function, the code block
wrapped within `run` will always run.

Hence making it non deterministic, since each execution can yield a different
result.

See [`How it works?`](how-it-works.html) to get a better idea of how Inngest
works.
