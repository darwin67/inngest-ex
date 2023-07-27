defmodule Inngest.Router.Invoke do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Config, Signature}
  alias Inngest.Function.Handler

  @content_type "application/json"

  def init(opts), do: opts
  def call(%{params: params} = conn, opts), do: exec(conn, Map.merge(opts, params))

  defp exec(
         %{request_path: path, private: %{raw_body: [body]}} = conn,
         %{"event" => event, "ctx" => ctx, "fnId" => fn_slug, funcs: funcs} = params
       ) do
    funcs = func_map(path, funcs)
    args = %{ctx: ctx, event: event, fn_slug: fn_slug, funcs: funcs, params: params}

    {status, payload} =
      case Config.is_dev() do
        true ->
          invoke(args)

        false ->
          with sig <- conn |> Plug.Conn.get_req_header("x-inngest-signature") |> List.first(),
               true <- Signature.signing_key_valid?(sig, Config.signing_key(), body) do
            invoke(args)
          else
            _ -> {400, Jason.encode!(%{error: "unable to verify signature"})}
          end
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, payload)
    |> halt()
  end

  # NOTES:
  # *********  RESPONSE  ***********
  # Each results has a specific meaning to it.
  # status, data
  # 206, generatorcode -> store result and continue execution
  # 200, resp -> execution completed (including steps) of function
  # 400, error -> non retriable error
  # 500, error -> retriable error
  @spec invoke(map()) :: {200 | 206 | 400 | 500, binary()}
  defp invoke(%{ctx: ctx, event: event, fn_slug: fn_slug, funcs: funcs, params: params} = _) do
    func = Map.get(funcs, fn_slug)

    args = %{
      event: Inngest.Event.from(event),
      run_id: Map.get(ctx, "run_id"),
      params: params
    }

    {status, resp} =
      func.mod.__handler__()
      |> Handler.invoke(args)

    payload =
      case Jason.encode(resp) do
        {:ok, val} -> val
        {:error, err} -> Jason.encode!(err.message)
      end

    {status, payload}
  end
end
