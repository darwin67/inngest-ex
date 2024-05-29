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
          ctx: %{event: map(), run_id: binary()},
          steps: map()
        }

  @type input_ret :: %{
          ctx: any(),
          steps: map()
        }

  @type output_args :: %{
          result: any(),
          step: any() | nil
        }

  @type output_ret :: %{
          result: %{data: any()}
        }

  @callback name() :: binary()

  @callback init() :: opts

  @callback transform_input(input_args, opts) :: map()

  @callback before_execution(opts) :: :ok

  @callback after_execution(opts) :: :ok

  @callback transform_output(output_args, opts) :: output_ret
end
