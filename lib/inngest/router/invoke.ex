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
    client = client!(opts)

    # Signature verification must use the original request body. Full-payload
    # expansion is an API convenience for execution, not part of the signed body.
    with :ok <- verify_signature(conn, client),
         {:ok, params} <- maybe_retrieve_full_payload(params, client) do
      exec(conn, Map.merge(opts, params), client)
    else
      {:error, :invalid_signature} ->
        send_signature_error(conn)

      {:error, error} ->
        send_error(conn, error)
    end
  end

  defp exec(
         conn,
         %{"event" => event, "events" => events, "ctx" => request_ctx, "fnId" => fn_slug} =
           params,
         client
       ) do
    func =
      client.funcs
      |> Enum.find(fn func ->
        Enum.member?(func.slugs(client.id), fn_slug)
      end)

    if is_nil(func) do
      raise RuntimeError, "function not found: #{fn_slug}"
    end

    # Context is for SDK internals and step tools. Input is the user-facing
    # function argument shape, so keep executor-only fields out of Input.
    ctx = %Inngest.Function.Context{
      attempt: Map.get(request_ctx, "attempt", 0),
      run_id: Map.get(request_ctx, "run_id"),
      disable_immediate_execution: Map.get(request_ctx, "disable_immediate_execution", false),
      stack: Map.get(request_ctx, "stack"),
      target_step_id: Map.get(params, "stepId", "step"),
      steps: Map.get(params, "steps"),
      # The ETS table tracks repeated step IDs within a single traversal so the
      # hash input follows the SDK spec: id, id:1, id:2, and so on.
      index: :ets.new(:index, [:set, :private])
    }

    input = %Inngest.Function.Input{
      event: Inngest.Event.from(event),
      events: Enum.map(events, &Inngest.Event.from/1),
      run_id: Map.get(request_ctx, "run_id"),
      attempt: Map.get(request_ctx, "attempt", 0),
      step: Inngest.StepTool
    }

    resp = invoke(func, ctx, input)

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
        func.handle_failure(ctx, input)
      else
        func.exec(ctx, input)
      end
      |> result_response(ctx)
    rescue
      non_retry in Inngest.NonRetriableError ->
        SdkResponse.from_result({:error, non_retry}, retry: false, stacktrace: __STACKTRACE__)

      retry in Inngest.RetryAfterError ->
        delay = Map.get(retry, :seconds)

        SdkResponse.from_result({:error, retry},
          retry: delay,
          stacktrace: __STACKTRACE__
        )

      step_error in Inngest.StepError ->
        SdkResponse.from_result({:error, step_error},
          retry: false,
          stacktrace: __STACKTRACE__
        )

      error ->
        SdkResponse.from_result({:error, error}, stacktrace: __STACKTRACE__)
    catch
      # Step tools throw GeneratorOpCode values to stop user code at the first
      # reportable step and return a 206 generator response to the executor.
      %GeneratorOpCode{} = opcode ->
        SdkResponse.from_result({:ok, [opcode]}, continue: true)

      error ->
        SdkResponse.from_result({:error, error}, stacktrace: __STACKTRACE__)
    end
  end

  # Targeted step requests ask this SDK to find one hashed step ID. If user code
  # completes without reporting it, the executor needs an explicit StepNotFound.
  defp result_response(_result, %{target_step_id: step_id}) when step_id not in [nil, "step"] do
    SdkResponse.from_result({:ok, [%GeneratorOpCode{id: step_id, op: "StepNotFound"}]},
      continue: true
    )
  end

  defp result_response(result, _ctx), do: SdkResponse.from_result(result, [])

  ## Helper functions to retrieve data from API

  defp fn_run_steps(run_id, client), do: fn_run_data(client, "/v0/runs/#{run_id}/actions")
  defp fn_run_batch(run_id, client), do: fn_run_data(client, "/v0/runs/#{run_id}/batch")

  defp verify_signature(conn, client) do
    if client.mode == :dev do
      :ok
    else
      sig = conn |> Plug.Conn.get_req_header(Headers.signature()) |> List.first()
      signing_keys = [client.signing_key, client.signing_key_fallback]

      if Signature.signing_key_valid?(sig, signing_keys, raw_body(conn)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  defp raw_body(%{private: %{raw_body: body}}) when is_list(body), do: Enum.join(body)
  defp raw_body(_conn), do: ""

  defp maybe_retrieve_full_payload(
         %{"ctx" => %{"use_api" => true, "run_id" => run_id}} = params,
         client
       ) do
    # The executor may send trimmed call payloads. When ctx.use_api is true,
    # fetch events and memoized actions before invoking user code.
    retrieve_steps = Task.async(fn -> fn_run_steps(run_id, client) end)
    retrieve_batch = Task.async(fn -> fn_run_batch(run_id, client) end)

    with {:ok, step_data} <- Task.await(retrieve_steps),
         {:ok, batch_data} <- Task.await(retrieve_batch) do
      # The spec treats the first full batch event as input.event.
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

  defp maybe_retrieve_full_payload(params, _client), do: {:ok, params}

  defp fn_run_data(client, path) do
    case Client.get(client, :api, path, []) do
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

  defp send_signature_error(conn) do
    error = RuntimeError.exception("unable to verify signature")
    resp = SdkResponse.from_result({:error, error}, retry: false)

    conn
    |> put_resp_content_type(@content_type)
    |> put_resp_header(Headers.sdk_version(), Config.sdk_version())
    |> put_resp_header(Headers.req_version(), Config.req_version())
    |> SdkResponse.maybe_retry_header(resp)
    |> send_resp(resp.status, resp.body)
    |> halt()
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
