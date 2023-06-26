defmodule Inngest.Function.Step do
  @moduledoc """
    A struct representing a function step
  """

  defstruct [
    :name,
    :slug,
    :step_type,
    :tags,
    :mod
  ]
end
