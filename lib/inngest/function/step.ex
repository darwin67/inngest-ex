defmodule Inngest.Function.Step do
  @moduledoc false

  defstruct [
    :id,
    :name,
    :path,
    :retries,
    :runtime
  ]

  def run(name, do: block) do
  end
end
