defmodule Inngest.Router.Invoke do
  @moduledoc false

  import Plug.Conn
  import Inngest.Router.Helper
  alias Inngest.{Client, Config, Headers, Signature, SdkResponse}
  alias Inngest.Function.GeneratorOpCode

  @content_type "application/json"

  def init(opts), do: opts

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(%{params: params} = conn, opts) do
    case maybe_retrieve_full_payload(params) do
      {:ok, params} ->
        exec(conn, Map.merge(opts, params))

      {:error, error} ->
        send_error(conn, error)
    end
  end

  defp exec(
         %{private: %{raw_body: [body]}} = conn,
         %{"event" => event, "events" => events, "ctx" => request_ctx, "fnId" => fn_slug} = params
       ) do
    func =
      params
      |> load_functions()
      |> Enum.find(fn func ->
        Enum.member?(func.slugs(), fn_slug)
      end)

    if is_nil(func) do
      raise RuntimeError, "function not found: #{fn_slug}"
    end

    ctx = %Inngest.Function.Context{
      attempt: Map.get(request_ctx, "attempt", 0),
      run_id: Map.get(request_ctx, "run_id"),
      disable_immediate_execution: Map.get(request_ctx, "disable_immediate_execution", false),
      stack: Map.get(request_ctx, "stack"),
      target_step_id: Map.get(params, "stepId", "step"),
      steps: Map.get(params, "steps"),
      index: :ets.new(:index, [:set, :private])
    }

    input = %Inngest.Function.Input{
      event: Inngest.Event.from(event),
      events: Enum.map(events, &Inngest.Event.from/1),
      run_id: Map.get(request_ctx, "run_id"),
      attempt: Map.get(request_ctx, "attempt", 0),
      step: Inngest.StepTool
    }

    resp =
      case Config.dev?() do
        true ->
          invoke(func, ctx, input)

        false ->
          with sig <- conn |> Plug.Conn.get_req_header(Headers.signature()) |> List.first(),
               signing_keys <- [Config.signing_key(), Config.signing_key_fallback()],
               true <- Signature.signing_key_valid?(sig, signing_keys, body) do
            invoke(func, ctx, input)
          else
            _ ->
              error = RuntimeError.exception("unable to verify signature")
              SdkResponse.from_result({:error, error}, retry: false)
          end
      end

    conn
    |> put_resp_content_type(@content_type)
    |> put_resp_header(Headers.sdk_version(), Config.sdk_version())
    |> put_resp_header(Headers.req_version(), Config.req_version())
    |> SdkResponse.maybe_retry_header(resp)
    |> send_resp(resp.status, resp.body)
    |> halt()
  rescue
    error ->
      send_error(conn, error, __STACKTRACE__)
  end

  defp invoke(func, ctx, input) do
    try do
      if failure?(input) do
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

  defp maybe_retrieve_full_payload(%{"ctx" => %{"use_api" => true, "run_id" => run_id}} = params) do
    retrieve_steps = Task.async(fn -> fn_run_steps(run_id) end)
    retrieve_batch = Task.async(fn -> fn_run_batch(run_id) end)

    with {:ok, step_data} <- Task.await(retrieve_steps),
         {:ok, batch_data} <- Task.await(retrieve_batch) do
      {:ok,
       Map.merge(params, %{
         "event" => List.first(batch_data, Map.get(params, "event")),
         "events" => batch_data,
         "steps" => step_data
       })}
    else
      {:error, error} ->
        {:error, RuntimeError.exception("failed to retrieve full payload: #{inspect(error)}")}
    end
  end

  defp maybe_retrieve_full_payload(params), do: {:ok, params}

  defp fn_run_data(path) do
    case Client.get(:api, path) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        # parse result just in case it isn't already parsed
        result =
          case body do
            _ = %{} -> body
            _ when is_list(body) -> body
            _ -> Jason.decode!(body)
          end

        {:ok, result}

      {:ok, %Tesla.Env{body: error}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_error(conn, error, stacktrace \\ []) do
    resp = SdkResponse.from_result({:error, error}, stacktrace: stacktrace)

    conn
    |> put_resp_content_type(@content_type)
    |> put_resp_header(Headers.sdk_version(), Config.sdk_version())
    |> put_resp_header(Headers.req_version(), Config.req_version())
    |> SdkResponse.maybe_retry_header(resp)
    |> send_resp(resp.status, resp.body)
    |> halt()
  end

  defp failure?(%{event: %{name: "inngest/function.failed"}} = _input), do: true
  defp failure?(_), do: false
end
