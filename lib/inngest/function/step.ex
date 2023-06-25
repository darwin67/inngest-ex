defmodule Inngest.Function.Step do
  @moduledoc false

  def run(_, _name, func) do
    func.()
  end
end
