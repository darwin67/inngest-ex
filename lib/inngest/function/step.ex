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

  @type t() :: %__MODULE__{
          name: binary(),
          slug: atom(),
          step_type: :step_run,
          tags: map(),
          mod: module()
        }
end
