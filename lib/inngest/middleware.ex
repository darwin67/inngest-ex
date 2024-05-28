defmodule Inngest.Middleware do
  @moduledoc """
  Inngest Middleware specification
  """

  @type opts ::
          binary()
          | tuple()
          | atom()
          | integer()
          | float()
          | [opts]
          | map()

  @callback init(opts) :: opts

  @callback transform_input(map(), opts) :: map()

  @callback before_memoization(map(), opts) :: map()

  @callback after_memoization(map(), opts) :: map()

  @callback before_execution(map(), opts) :: map()

  @callback after_execution(map(), opts) :: map()

  @callback transform_output(map(), opts) :: map()

  @callback before_response(map(), opts) :: map()

  @callback before_send_events(map(), opts) :: map()

  @callback after_send_events(map(), opts) :: map()
end
