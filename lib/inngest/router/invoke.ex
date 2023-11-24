defmodule Inngest.Router.Invoke do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Config, Headers, Signature, SdkResponse}
  alias Inngest.Function.GeneratorOpCode

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
    func =
      params
      |> load_functions()
      |> func_map(path)
      |> Map.get(fn_slug)

    ctx = %Inngest.Function.Context{
      attempt: Map.get(ctx, "attempt", 0),
      run_id: Map.get(ctx, "run_id"),
      stack: Map.get(ctx, "stack"),
      steps: Map.get(params, "steps")
    }

    input = %Inngest.Function.Input{
      event: Inngest.Event.from(event),
      events: Enum.map(events, &Inngest.Event.from/1),
      run_id: Map.get(ctx, "run_id"),
      step: Inngest.StepTool
    }

    resp =
      case Config.is_dev() do
        true ->
          invoke(func, ctx, input)

        false ->
          with sig <- conn |> Plug.Conn.get_req_header(Headers.signature()) |> List.first(),
               true <- Signature.signing_key_valid?(sig, Config.signing_key(), body) do
            invoke(func, ctx, input)
          else
            _ ->
              SdkResponse.from_result({:error, "unable to verify signature"}, retry: false)
          end
      end

    conn
    |> put_resp_content_type(@content_type)
    |> put_resp_header(Headers.sdk_version(), Config.sdk_version())
    |> SdkResponse.maybe_retry_header(resp)
    |> send_resp(resp.status, resp.body)
    |> halt()
  end

  defp invoke(func, ctx, input) do
    try do
      func.mod.exec(ctx, input) |> SdkResponse.from_result([])
    rescue
      non_retry in Inngest.NonRetriableError ->
        SdkResponse.from_result({:error, non_retry}, retry: false, stacktrace: __STACKTRACE__)

      retry in Inngest.RetryAfterError ->
        delay = Map.get(retry, :seconds)

        SdkResponse.from_result({:error, retry.message},
          retry: delay,
          stacktrace: __STACKTRACE__
        )

      error ->
        SdkResponse.from_result({:error, error}, stacktrace: __STACKTRACE__)
    catch
      # Finished step, report back to executor
      %GeneratorOpCode{} = opcode ->
        SdkResponse.from_result({:ok, [opcode]}, continue: true)

      error ->
        SdkResponse.from_result({:error, error}, stacktrace: __STACKTRACE__)
    end
  end

  ## Helper functions to retrieve data from API

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
