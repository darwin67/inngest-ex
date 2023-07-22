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

    router_opts = [as: false, alias: false]

    quote location: :keep, bind_quoted: binding() do
      scope path, alias: false, as: false do
        post "/", Inngest.Router.Invoke, opts, router_opts
        put "/", Inngest.Router.Register, opts, router_opts
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
