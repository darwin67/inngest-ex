defmodule Inngest.HTTPClient.Response do
  @moduledoc """
  SDK-owned outbound HTTP response shape.
  """

  @type header() :: {binary(), binary()}

  @type t() :: %__MODULE__{
          status: non_neg_integer(),
          headers: [header()],
          body: term()
        }

  defstruct [
    :status,
    body: nil,
    headers: []
  ]
end
