# Used by "mix format" and to export configuration.
export_locals_without_parens = [
  plug: 1,
  plug: 2,
  forward: 2,
  forward: 3,
  forward: 4,
  match: 2,
  match: 3,
  get: 2,
  get: 3,
  get: 4,
  head: 2,
  head: 3,
  post: 2,
  post: 3,
  post: 4,
  put: 2,
  put: 3,
  put: 4,
  patch: 2,
  patch: 3,
  patch: 4,
  delete: 2,
  delete: 3,
  delete: 4,
  options: 2,
  options: 3,
  options: 4,
  live: 3,
  live: 4,
  live_session: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
