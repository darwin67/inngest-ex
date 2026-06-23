defmodule Inngest.Router.Phoenix do
  @moduledoc """
  Router module expected to be used with a `Phoenix` router.

  ## Examples
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Inngest.Router, :phoenix

        scope "/" do
          pipe_through(:api)

          inngest("/api/inngest", client: MyApp.Inngest)
        end
      end

  Inngest verifies inbound request signatures against the raw request body. In
  Phoenix applications, configure `Plug.Parsers` with
  `Inngest.CacheBodyReader` in your endpoint so the router can verify signed
  requests:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        body_reader: {Inngest.CacheBodyReader, :read_body, []},
        json_decoder: Phoenix.json_library()

      plug MyAppWeb.Router
  """
  @framework "phoenix"

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
      |> Inngest.Router.Helper.require_client!()
      |> Map.put(:framework, @framework)
      |> Macro.escape()

    router_opts = [as: false, alias: false]

    quote location: :keep, bind_quoted: binding() do
      scope path, alias: false, as: false do
        get "/", Inngest.Router.Introspection, opts, router_opts
        post "/", Inngest.Router.Invoke, opts, router_opts
        put "/", Inngest.Router.Register, opts, router_opts
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
