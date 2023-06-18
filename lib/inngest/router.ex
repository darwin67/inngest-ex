defmodule Inngest.Router do
  @moduledoc """
  Router module for Inngest to be integrated with apps that
  have a router.

  Currently assuming Phonenix as the main option
  """

  defmacro inngest_phx(path, opts \\ []) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    scope =
      quote bind_quoted: binding() do
        scope path, alias: false, as: false do
          {session_name, session_opts, route_opts} = Inngest.Router.__options__(opts)

          import Phoenix.Router, only: [put: 4]
          # import Phoenix.LiveView.Route, only: [live: 4, live_session: 3]

          live_session session_name, session_opts do
            # live "/", Inngest.Router.PageLive, :home, route_opts
            put "/", Inngest.Router.API, :register, route_opts
          end
        end
      end

    # Remove check once we require Phoenix v1.7
    if Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
      quote do
        unquote(scope)

        unless Module.get_attribute(__MODULE__, :inngest_prefix) do
          @inngest_prefix Phoenix.Router.scoped_path(__MODULE__, path)
          def __inngest_prefix__, do: @inngest_prefix
        end
      end
    else
      scope
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other

  @doc false
  def __options__(opts) do
    live_socket_path = Keyword.get(opts, :live_socket_path, "/live")

    funcs = Keyword.get(opts, :funcs, [])

    csp_nonce_assign_key =
      case opts[:csp_nonce_assign_key] do
        nil -> nil
        key when is_atom(key) -> %{img: key, style: key, script: key}
        %{} = keys -> Map.take(keys, [:img, :style, :script])
      end

    {
      opts[:live_session_name] || :inngest,
      [
        session: {__MODULE__, :__session__, []},
        root_layout: false
      ],
      [
        private: %{
          live_socket_path: live_socket_path,
          csp_nonce_assign_key: csp_nonce_assign_key
        },
        assigns: %{
          funcs: funcs
        },
        as: :inngest
      ]
    }
  end
end
