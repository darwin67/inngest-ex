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

  @type input_args :: %{
          ctx: Inngest.Function.Input,
          steps: list(map())
        }

  @type input_ret :: %{
          ctx: Inngest.Function.Input,
          steps: list(map())
        }

  @type output_args :: %{
          result: %{data: any()},
          step: Inngest.GeneratorOpCode.t() | nil
        }

  @type output_ret :: %{
          result: %{data: any()}
        }

  @callback name() :: binary()

  # NOTE: what to make available on init?
  @callback init(opts) :: opts

  @callback transform_input(input_args, opts) :: input_ret

  @callback transform_output(output_args, opts) :: output_ret

  @callback before_memoization(opts) :: :ok

  @callback after_memoization(opts) :: :ok

  @callback before_execution(opts) :: :ok

  @callback after_execution(opts) :: :ok

  @optional_callbacks transform_input: 2,
                      transform_output: 2,
                      before_memoization: 1,
                      after_memoization: 1,
                      before_execution: 1,
                      after_execution: 1
end
