defmodule Inngest.Router.Plug do
  @moduledoc """
  Router module expected to be used with a `Plug.Router`.

  ## Examples
      use Inngest.Router, :plug

  Generated Inngest routes parse JSON and urlencoded request bodies with
  `Inngest.CacheBodyReader` before invoking functions or syncing
  registrations. If your router runs another `Plug.Parsers` plug before
  dispatching to Inngest, configure that parser with `Inngest.CacheBodyReader`
  so signed requests can still be verified against the raw request body.
  """
  @framework "plug"
  @parser_opts [
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason
  ]

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
      |> Inngest.Router.Helper.require_client!()
      |> Map.put(:framework, @framework)
      |> Macro.escape()

    quote location: :keep do
      # introspection path
      get unquote(path) do
        opts = Inngest.Router.Introspection.init(unquote(opts))

        var!(conn)
        |> Inngest.Router.Introspection.call(opts)
      end

      # invoke path
      post unquote(path) do
        opts = Inngest.Router.Invoke.init(unquote(opts))

        var!(conn)
        |> Inngest.Router.Plug.__parse_body__(unquote(path))
        |> Inngest.Router.Invoke.call(opts)
      end

      # register path
      put unquote(path) do
        opts = Inngest.Router.Register.init(unquote(opts))

        var!(conn)
        |> Inngest.Router.Plug.__parse_body__(unquote(path))
        |> Inngest.Router.Register.call(opts)
      end
    end
  end

  @doc false
  def __parse_body__(conn, path) do
    opts =
      @parser_opts
      |> Keyword.put(:body_reader, {Inngest.CacheBodyReader, :read_body, [[paths: [path]]]})
      |> Plug.Parsers.init()

    Plug.Parsers.call(conn, opts)
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
