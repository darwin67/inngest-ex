defmodule Inngest.Router.Phoenix do
  @moduledoc """
  Router module expected to be used with a phoenix router
  """

  defmacro __using__(_opts) do
    quote do
    end
  end

  defmacro inngest(path, opts) do
    quote location: :keep do
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
