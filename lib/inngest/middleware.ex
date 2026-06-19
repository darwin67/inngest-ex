defmodule Inngest.Middleware do
  @moduledoc """
  Behaviour for SDK middleware.

  Middleware modules can implement any subset of the callbacks below. Configure
  middleware on a client with `use Inngest.Client, middleware: [...]` or on an
  individual function with `middleware` in `Inngest.FnOpts`.

  Middleware entries run in registration order. Client-level entries run before
  function-level entries for function execution and step sends.

  Entries may be modules or `{module, opts}` tuples:

      use Inngest.Client,
        id: "my-app",
        funcs: [MyApp.Functions.Sync],
        middleware: [
          MyApp.Inngest.RequestLogger,
          {MyApp.Inngest.TenantMiddleware, tenant_header: "x-tenant-id"}
        ]

  ## Function Lifecycle

  `transform_input/3` and `before_execution/3` receive the internal
  `Inngest.Function.Context` and user-facing `Inngest.Function.Input`. Return
  `{ctx, input}` or `{:ok, ctx, input}`.

  `after_execution/4` and `transform_output/4` receive the function result
  tuple before it is converted into an SDK response. Return the updated result
  tuple, such as `{:ok, output}` or `{:error, reason}`.

  `before_response/4` receives the generated SDK response struct and can mutate
  the final response body, status, or retry metadata before the router sends it.

  ## Events And Steps

  `before_send_events/3` can mutate events before they are sent to Inngest.
  `after_send_events/4` can mutate and must return the `Inngest.Client.send/2`
  result tuple.

  `after_memoization/4` and `transform_step_data/4` run on memoized step data
  before user code receives it.
  """

  alias Inngest.Function.{Context, Input}

  @type opts() :: Keyword.t()
  @type entry() :: module() | {module(), opts()}
  @type normalized_entry() :: {module(), opts()}
  @type result() :: {:ok, term()} | {:error, term()}

  @doc """
  Mutates the function context and input before execution setup continues.

  This is the earliest function lifecycle hook. Use it to normalize incoming
  event data or add derived values to `Inngest.Function.Context.data` before
  later middleware or function code runs.
  """
  @callback transform_input(Context.t(), Input.t(), opts()) ::
              {Context.t(), Input.t()} | {:ok, Context.t(), Input.t()}

  @doc """
  Runs immediately before the user function is called.

  This hook receives the context and input after `transform_input/3` has
  completed for all middleware. Use it for request-aware setup, authorization,
  tenancy, or tracing data that should be available to function code.
  """
  @callback before_execution(Context.t(), Input.t(), opts()) ::
              {Context.t(), Input.t()} | {:ok, Context.t(), Input.t()}

  @doc """
  Mutates the raw function result after user code returns.

  Return the updated result tuple directly, such as `{:ok, value}` or
  `{:error, reason}`. This hook runs before `transform_output/4`.
  """
  @callback after_execution(Context.t(), Input.t(), result(), opts()) :: result()

  @doc """
  Mutates the function result before it is converted to an SDK response.

  Use this hook for output normalization or error shaping that should happen
  before the router serializes the response body and retry metadata.
  """
  @callback transform_output(Context.t(), Input.t(), result(), opts()) :: result()

  @doc """
  Mutates the SDK response immediately before the router sends it.

  This hook can adjust the final status, body, or retry metadata after result
  serialization. Return the response struct directly or `{:ok, response}`.
  """
  @callback before_response(Context.t(), Input.t(), term(), opts()) ::
              term() | {:ok, term()}

  @doc """
  Mutates outbound events before they are sent to Inngest.

  This hook runs for both `Inngest.Client.send/2` and
  `Inngest.StepTool.send_event/3`. Return a list of events or
  `{:ok, events}`.
  """
  @callback before_send_events([Inngest.Event.t()], term(), opts()) ::
              [Inngest.Event.t()] | {:ok, [Inngest.Event.t()]}

  @doc """
  Mutates the event-send result after the HTTP request completes.

  Return the updated `Inngest.Client.send/2` result tuple directly. The second
  argument contains the events after `before_send_events/3` mutations.
  """
  @callback after_send_events(
              Inngest.Client.send_result(),
              [Inngest.Event.t()],
              term(),
              opts()
            ) :: Inngest.Client.send_result()

  @doc """
  Mutates a memoized step value immediately after it is unwrapped.

  This hook only runs when the executor has already memoized a step. Use it for
  compatibility migrations or shared decoding before user code receives replayed
  step data.
  """
  @callback after_memoization(Context.t(), binary(), term(), opts()) :: term() | {:ok, term()}

  @doc """
  Mutates memoized step data before it is returned to user code.

  This hook runs after `after_memoization/4` and receives the hashed step ID and
  current value. Return the transformed value directly or `{:ok, value}`.
  """
  @callback transform_step_data(Context.t(), binary(), term(), opts()) :: term() | {:ok, term()}

  @optional_callbacks transform_input: 3,
                      before_execution: 3,
                      after_execution: 4,
                      transform_output: 4,
                      before_response: 4,
                      before_send_events: 3,
                      after_send_events: 4,
                      after_memoization: 4,
                      transform_step_data: 4

  @doc false
  @spec normalize(nil | entry() | [entry()]) :: [normalized_entry()]
  def normalize(nil), do: []

  def normalize(entries) when is_list(entries) do
    Enum.map(entries, &normalize_entry/1)
  end

  def normalize(entry), do: normalize([entry])

  @doc false
  @spec function_middleware(module()) :: [normalized_entry()]
  def function_middleware(func) do
    if Code.ensure_loaded?(func) and function_exported?(func, :middleware, 0) do
      func.middleware()
    else
      []
    end
  end

  @doc false
  @spec for_function(Inngest.Client.t(), module()) :: [normalized_entry()]
  def for_function(%{middleware: middleware}, func) do
    middleware ++ function_middleware(func)
  end

  @doc false
  @spec run_transform_input([normalized_entry()], Context.t(), Input.t()) ::
          {Context.t(), Input.t()}
  def run_transform_input(middleware, ctx, input) do
    run_context_input(middleware, :transform_input, ctx, input)
  end

  @doc false
  @spec run_before_execution([normalized_entry()], Context.t(), Input.t()) ::
          {Context.t(), Input.t()}
  def run_before_execution(middleware, ctx, input) do
    run_context_input(middleware, :before_execution, ctx, input)
  end

  @doc false
  @spec run_after_execution([normalized_entry()], Context.t(), Input.t(), result()) :: result()
  def run_after_execution(middleware, ctx, input, result) do
    run_result(middleware, :after_execution, ctx, input, result)
  end

  @doc false
  @spec run_transform_output([normalized_entry()], Context.t(), Input.t(), result()) :: result()
  def run_transform_output(middleware, ctx, input, result) do
    run_result(middleware, :transform_output, ctx, input, result)
  end

  @doc false
  @spec run_before_response(
          [normalized_entry()],
          Context.t(),
          Input.t(),
          Inngest.SdkResponse.t()
        ) :: Inngest.SdkResponse.t()
  def run_before_response(middleware, ctx, input, response) do
    Enum.reduce(middleware, response, fn {module, opts}, acc ->
      if callback?(module, :before_response, 4) do
        module
        |> apply(:before_response, [ctx, input, acc, opts])
        |> unwrap_value(:before_response)
      else
        acc
      end
    end)
  end

  @doc false
  @spec run_before_send_events([normalized_entry()], [Inngest.Event.t()], term()) ::
          [Inngest.Event.t()]
  def run_before_send_events(middleware, events, context) do
    Enum.reduce(middleware, events, fn {module, opts}, acc ->
      if callback?(module, :before_send_events, 3) do
        module
        |> apply(:before_send_events, [acc, context, opts])
        |> unwrap_value(:before_send_events)
        |> List.wrap()
      else
        acc
      end
    end)
  end

  @doc false
  @spec run_after_send_events(
          [normalized_entry()],
          Inngest.Client.send_result(),
          [Inngest.Event.t()],
          term()
        ) :: Inngest.Client.send_result()
  def run_after_send_events(middleware, result, events, context) do
    Enum.reduce(middleware, result, fn {module, opts}, acc ->
      if callback?(module, :after_send_events, 4) do
        apply(module, :after_send_events, [acc, events, context, opts])
      else
        acc
      end
    end)
  end

  @doc false
  @spec run_after_memoization([normalized_entry()], Context.t(), binary(), term()) :: term()
  def run_after_memoization(middleware, ctx, step_id, value) do
    run_step_value(middleware, :after_memoization, ctx, step_id, value)
  end

  @doc false
  @spec run_transform_step_data([normalized_entry()], Context.t(), binary(), term()) :: term()
  def run_transform_step_data(middleware, ctx, step_id, value) do
    run_step_value(middleware, :transform_step_data, ctx, step_id, value)
  end

  defp normalize_entry(module) when is_atom(module), do: {module, []}
  defp normalize_entry({module, opts}) when is_atom(module) and is_list(opts), do: {module, opts}

  defp normalize_entry(entry) do
    raise ArgumentError, "invalid Inngest middleware entry: #{inspect(entry)}"
  end

  defp run_context_input(middleware, callback, ctx, input) do
    Enum.reduce(middleware, {ctx, input}, fn {module, opts}, {ctx_acc, input_acc} ->
      if callback?(module, callback, 3) do
        module
        |> apply(callback, [ctx_acc, input_acc, opts])
        |> unwrap_context_input(callback)
      else
        {ctx_acc, input_acc}
      end
    end)
  end

  defp run_result(middleware, callback, ctx, input, result) do
    Enum.reduce(middleware, result, fn {module, opts}, acc ->
      if callback?(module, callback, 4) do
        apply(module, callback, [ctx, input, acc, opts])
      else
        acc
      end
    end)
  end

  defp run_step_value(middleware, callback, ctx, step_id, value) do
    Enum.reduce(middleware, value, fn {module, opts}, acc ->
      if callback?(module, callback, 4) do
        module
        |> apply(callback, [ctx, step_id, acc, opts])
        |> unwrap_value(callback)
      else
        acc
      end
    end)
  end

  defp callback?(module, callback, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, callback, arity)
  end

  defp unwrap_context_input({:ok, %Context{} = ctx, %Input{} = input}, _callback),
    do: {ctx, input}

  defp unwrap_context_input({%Context{} = ctx, %Input{} = input}, _callback),
    do: {ctx, input}

  defp unwrap_context_input(value, callback) do
    raise ArgumentError,
          "#{inspect(callback)} middleware callback returned invalid value: #{inspect(value)}"
  end

  defp unwrap_value({:ok, value}, _callback), do: value
  defp unwrap_value(value, _callback), do: value
end
