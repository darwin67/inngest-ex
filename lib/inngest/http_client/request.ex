defmodule Inngest.HTTPClient.Request do
  @moduledoc """
  SDK-owned outbound HTTP request shape.

  `url` is the executable request target. The separate `base_url`, `path`, and
  `query` fields are preserved for tests, diagnostics, and custom adapters that
  want to route or pool by request role without reparsing URLs.
  """

  @type method() :: :get | :post | :put | :patch | :delete
  @type header() :: {binary(), binary()}

  @type t() :: %__MODULE__{
          method: method(),
          base_url: binary(),
          path: binary(),
          query: Enumerable.t() | nil,
          url: binary(),
          headers: [header()],
          body: term(),
          pool_timeout: timeout(),
          receive_timeout: timeout(),
          request_timeout: timeout(),
          adapter_opts: Keyword.t()
        }

  defstruct [
    :method,
    :base_url,
    :path,
    :query,
    :url,
    :body,
    pool_timeout: 5_000,
    receive_timeout: 10_000,
    request_timeout: 15_000,
    headers: [],
    adapter_opts: []
  ]
end
