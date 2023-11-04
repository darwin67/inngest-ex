defmodule Inngest.Router.Invoke do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Config, Signature, Handler, Utils}

  @content_type "application/json"

  defdelegate httpclient(type, opts), to: Inngest.Client

  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(
        %{params: %{"use_api" => use_api, "ctx" => %{"run_id" => run_id}} = params} = conn,
        opts
      ) do
    with true <- use_api,
         retrieve_steps <- Task.async(fn -> fn_run_steps(run_id) end),
         retrieve_batch <- Task.async(fn -> fn_run_batch(run_id) end),
         {:ok, step_data} <- Task.await(retrieve_steps),
         {:ok, batch_data} <- Task.await(retrieve_batch) do
      params =
        Map.merge(params, %{
          "step" => step_data,
          "events" => batch_data
        })

      exec(conn, Map.merge(opts, params))
    else
      _ -> exec(conn, Map.merge(opts, params))
    end
  end

  defp exec(
         %{request_path: path, private: %{raw_body: [body]}} = conn,
         %{"event" => event, "events" => events, "ctx" => ctx, "fnId" => fn_slug} = params
       ) do
    funcs =
      params
      |> load_functions()
      |> func_map(path)

    args = %{
      ctx: struct(Inngest.Handler.Context, Utils.keys_to_atoms(ctx)),
      event: event,
      events: events,
      fn_slug: fn_slug,
      funcs: funcs,
      params: params
    }

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
  defp invoke(%{ctx: ctx, event: event, events: events, fn_slug: fn_slug, funcs: funcs} = _) do
    func = Map.get(funcs, fn_slug)

    {status, resp} =
      %Handler{
        ctx: ctx,
        event: Inngest.Event.from(event),
        events: Enum.map(events, &Inngest.Event.from/1),
        run_id: Map.get(ctx, "run_id"),
        step: Inngest.StepTool
      }
      |> Handler.invoke(func.mod)

    payload =
      case Jason.encode(resp) do
        {:ok, val} -> val
        {:error, err} -> Jason.encode!(err.message)
      end

    {status, payload}
  end

  defp fn_run_steps(run_id), do: fn_run_data("/v0/runs/#{run_id}/actions")
  defp fn_run_batch(run_id), do: fn_run_data("/v0/runs/#{run_id}/batch")

  defp fn_run_data(path) do
    key = Signature.hashed_signing_key(Config.signing_key())
    headers = if is_nil(key), do: [], else: [authorization: "Bearer " <> key]

    headers =
      if is_nil(Config.env()),
        do: headers,
        else: Keyword.put(headers, :"x-inngest-env", Config.env())

    case httpclient(:api, headers: headers) |> Tesla.get(path) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        # parse result just in case it isn't already parsed
        result =
          case body do
            _ = %{} -> body
            _ -> Jason.decode!(body)
          end

        {:ok, result}

      {:ok, %Tesla.Env{body: error}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end
end
