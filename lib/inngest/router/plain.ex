defmodule Inngest.Router.Plain do
  @moduledoc """
  Router module expected to be used with a plain
  router
  """

  defmacro __using__(_opts) do
    quote do
      use Plug.Router
      import Inngest.Router.Plain

      plug Plug.Logger

      plug Plug.Parsers,
        parsers: [:urlencoded, :json],
        pass: ["text/*"],
        json_decoder: Jason

      plug :match
      plug :dispatch
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
               Map.put(x, slug, func.serve())
             end)

      post unquote(path) do
        conn = var!(conn)
        params = params(conn)

        conn
        |> assign(:funcs, @funcs)
        |> Inngest.Router.Endpoint.invoke(params)
      end

      # register path
      put unquote(path) do
        conn = var!(conn)
        params = params(conn)

        conn
        |> Inngest.Router.Endpoint.register(params)
      end

      defp params(conn) do
        conn
        |> Map.get(:params, %{})
        |> Map.merge(unquote(opts))
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
