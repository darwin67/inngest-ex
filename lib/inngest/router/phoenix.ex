defmodule Inngest.Router.Phoenix do
  @moduledoc """
  Router module expected to be used with a phoenix router
  """

  defmacro __using__(_opts) do
    quote do
      import Inngest.Router.Phoenix
    end
  end

  defmacro inngest(path, opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end
      |> Enum.into(%{})
      |> Macro.escape()

    quote location: :keep do
      # create mapping of function slug to function map
      # during compile time
      @funcs unquote(opts)
             |> Map.get(:funcs, %{})
             |> Enum.reduce(%{}, fn func, x ->
               slug = func.slug()
               Map.put(x, slug, func.serve(unquote(path)))
             end)

      scope unquote(path) do
        post "/", Inngest.Router.Endpoint, :invoke
        put "/", Inngest.Router.Endpoint, :register
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
