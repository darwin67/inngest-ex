defmodule Inngest.Handler do
  @moduledoc false

  # def register(funcs) do
  #   # load config
  #   # loop through functions
  #   #   construct inngest function for registration
  #   # send registration request
  # end
end

defmodule Inngest.SDK.RegisterRequest do
  @moduledoc """
  RegisterRequest represents a new deploy request from SDK-based functions.
  This lets us know that a new deploy has started and that we need to upsert
  function definitions from the newly deployed endpoint.
  """

  defstruct [
    # Represents the entire URL which hosts the functions, e.g.
    # https://www.example.com/api/v1/inngest
    :url,
    # Represents the SDK language and version used for these functions,
    # in the format: "elixir:v0.1.0"
    :sdk,
    # Represents the framework used to host these functions. For example,
    # using the JS SDK, we support NextJS, Netlify, Express, etc via middlware
    # to initlize the SDK handler. This lets us gather stats on usage.
    :framework,
    # Represents a namespaces app name for each deployed function.
    :app_name,
    # Represents all functions hosted within this deploy.
    :functions,
    # Headers are fetched from the incoming HTTP request. They are present
    # on all calls to Inngest from the SDK, and are separate from the
    # `RegisterRequest` JSON payload to have a single source of truth.
    :headers,
    # Used for memorization
    :checksum,

    # The version for this response, which let's us upgrade the SDKs and APIs
    # with backwards compatibility
    v: "1",
    # Represents how this was deployed, e.g. via a ping. This allows us
    # to change flows in the future, or support multiple registration flows
    # within a single fetch response
    deploy_type: "ping"
  ]
end
