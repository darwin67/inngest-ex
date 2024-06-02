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
         %{private: %{raw_body: [body]}} = conn,
         %{"event" => event, "events" => events, "ctx" => ctx, "fnId" => fn_slug} = params
       ) do
    input = %Inngest.Function.Input{
      attempt: Map.get(ctx, "attempt", 0),
      event: Inngest.Event.from(event),
      events: Enum.map(events, &Inngest.Event.from/1),
      run_id: Map.get(ctx, "run_id"),
      step: Inngest.StepTool
    }

    # prepare steps to be passed into middlewares
    steps =
      case get_in(params, ["ctx", "stack", "stack"]) do
        nil ->
          []

        stack ->
          Enum.into(stack, [], fn hash ->
            data = get_in(params, ["steps", hash])
            %{id: hash, data: data}
          end)
      end

    func =
      params
      |> load_functions()
      |> Enum.find(fn func ->
        Enum.member?(func.slugs(), fn_slug)
      end)

    # Initialize middlewares
    middleware =
      params
      |> load_middleware()
      |> Enum.into(%{}, fn mid ->
        arg = %{input: input, func: func, steps: steps}
        opts = mid.init(arg)
        {mid.name(), %{opts: opts, mid: mid}}
      end)

    # Transform inputs
    steps =
      steps
      # TODO: Apply each middleware to the step data
      # |> Stream.map(fn step ->
      # end)
      |> Enum.into(%{}, fn %{id: id, data: data} ->
        {id, data}
      end)

    fnctx = %Inngest.Function.Context{
      steps: steps,
      middleware: middleware,
      index: :ets.new(:index, [:set, :private])
    }

    resp =
      case Config.is_dev() do
        true ->
          invoke(func, fnctx, input)

        false ->
          with sig <- conn |> Plug.Conn.get_req_header(Headers.signature()) |> List.first(),
               true <- Signature.signing_key_valid?(sig, Config.signing_key(), body) do
            invoke(func, fnctx, input)
          else
            _ ->
              SdkResponse.from_result({:error, "unable to verify signature"}, retry: false)
          end
      end

    conn
    |> put_resp_content_type(@content_type)
    |> put_resp_header(Headers.sdk_version(), Config.sdk_version())
    |> put_resp_header(Headers.req_version(), Config.req_version())
    |> SdkResponse.maybe_retry_header(resp)
    |> send_resp(resp.status, resp.body)
    |> halt()
  end

  defp invoke(func, ctx, input) do
    try do
      if is_failure?(input) do
        func.handle_failure(ctx, input) |> SdkResponse.from_result([])
      else
        func.exec(ctx, input) |> SdkResponse.from_result([])
      end
    rescue
      non_retry in Inngest.NonRetriableError ->
        SdkResponse.from_result({:error, non_retry}, retry: false, stacktrace: __STACKTRACE__)

      retry in Inngest.RetryAfterError ->
        delay = Map.get(retry, :seconds)

        SdkResponse.from_result({:error, retry},
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

  defp is_failure?(%{event: %{name: "inngest/function.failed"}} = _input), do: true
  defp is_failure?(_), do: false
end
