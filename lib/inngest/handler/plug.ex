defmodule Inngest.Router.Plug do
  @moduledoc """
  Router module expected to be used with a `Plug.Router`.

  ## Examples
      use Inngest.Router, :plug
  """
  @framework "plug"

  defmacro __using__(_opts) do
    quote do
      import Inngest.Router.Plug
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
      |> Inngest.Router.Helper.load_functions_from_path()
      |> Inngest.Router.Helper.load_middleware_from_path()
      |> Map.put(:framework, @framework)
      |> Macro.escape()

    quote location: :keep do
      # invoke path
      post unquote(path) do
        opts = Inngest.Router.Invoke.init(unquote(opts))

        var!(conn)
        |> Inngest.Router.Invoke.call(opts)
      end

      # register path
      put unquote(path) do
        opts = Inngest.Router.Register.init(unquote(opts))

        var!(conn)
        |> Inngest.Router.Register.call(opts)
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
