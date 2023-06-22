defmodule Inngest.Router.Register do
  import Plug.Conn

  def call(conn, _opts) do
    resp = Jason.encode!(%{register: false})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp)
  end
end

defmodule Inngest.Router.Plain do
  @moduledoc """
  Router module expected to be used with a plain
  router
  """

  defmacro inngest(path, opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote location: :keep do
      # register path
      put unquote(path) do
        conn
        |> Inngest.Router.Register.call(unquote(opts))
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:inngest, 2}})

  defp expand_alias(other, _env), do: other
end
