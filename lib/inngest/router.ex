defmodule Inngest.Router do
  @moduledoc """
  Router module for Inngest to be integrated with apps that
  have a router.

  Currently assuming Phonenix as the main option
  """

  defmacro inngest(path, opts \\ []) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    # scope =
    #   quote bind_quoted: binding() do
    #     scope path, alias: false, as: false do
    #       {session_name, session_opts, route_opts} = Inngest.Router.__options__(opts)

    #       import Phoenix.Router, only: [post: 4, put: 4]
    #       import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

    #       post "/", Inngest.Router.Endpoint, :invoke, route_opts |> Inngest.Router.reduce_funcs()
    #       put "/", Inngest.Router.Endpoint, :register, route_opts

    #       live_session session_name, session_opts do
    #         live "/",
    #              Inngest.Live.InngestLive.Dev,
    #              :dev_view,
    #              route_opts |> Keyword.drop([:assigns])
    #       end
    #     end
    #   end

    # # Remove check once we require Phoenix v1.7
    # if Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
    #   quote do
    #     unquote(scope)

    #     unless Module.get_attribute(__MODULE__, :inngest_prefix) do
    #       @inngest_prefix Phoenix.Router.scoped_path(__MODULE__, path)
    #       def __inngest_prefix__, do: @inngest_prefix
    #     end
    #   end
    # else
    #   scope
    # end
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

    allow_destructive_actions = opts[:allow_destructive_actions] || false

    session_args = [
      allow_destructive_actions,
      csp_nonce_assign_key
    ]

    {
      opts[:live_session_name] || :inngest,
      [
        session: {__MODULE__, :__session__, session_args},
        root_layout: false,
        on_mount: opts[:on_mount] || nil
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

  def __session__(
        conn,
        allow_destructive_actions,
        csp_nonce_assign_key
      ) do
    %{
      "allow_destructive_actions" => allow_destructive_actions,
      "csp_nonces" => %{
        img: conn.assigns[csp_nonce_assign_key[:img]],
        style: conn.assigns[csp_nonce_assign_key[:style]],
        script: conn.assigns[csp_nonce_assign_key[:script]]
      }
    }
  end

  @spec reduce_funcs(Keyword.t()) :: Keyword.t()
  def reduce_funcs(keywords) do
    funcs =
      keywords
      |> Keyword.get(:assigns, %{})
      |> Map.get(:funcs, %{})

    dict =
      Enum.reduce(funcs, %{}, fn func, x ->
        slug = func.slug()
        x |> Map.put(slug, func.serve())
      end)

    keywords |> Keyword.put(:assigns, %{funcs: dict})
  end
end
