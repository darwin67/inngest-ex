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

  ## Hook Shape

  Callbacks receive an `args` map and the middleware entry `opts`. Transform
  hooks return the updated `args` map. Wrap hooks receive `args.next`, a
  zero-arity function that continues the middleware chain, and return the
  wrapped result.

  Middleware modules only need to define the callbacks they use. All callbacks
  are optional, so a middleware can implement a single hook without defining
  no-op functions for the rest.

  This follows the current TypeScript SDK middleware model while using Elixir
  behaviour modules instead of classes.
  """

  alias Inngest.Function.{Context, Input}

  @type opts() :: Keyword.t()
  @type entry() :: module() | {module(), opts()}
  @type normalized_entry() :: {module(), opts()}
  @type args() :: map()
  @type result() :: {:ok, term()} | {:error, term()}

  @doc """
  Runs when middleware is registered on a client or function.

  `args.client` contains the runtime client. `args.function` is `nil` for
  client-level registration and the function module for function-level
  registration.
  """
  @callback on_register(args(), opts()) :: term()

  @doc """
  Mutates outbound events before they are sent to Inngest.

  This hook runs for both `Inngest.Client.send/2` and
  `Inngest.StepTool.send_event/3`. Return the updated args map with an `:events`
  key.
  """
  @callback transform_send_event(args(), opts()) :: args() | {:ok, args()}

  @doc """
  Wraps event sending.

  `args.next` sends the events and returns the normal `Inngest.Client.send/2`
  result tuple. Use this hook for metrics, backups, or result shaping around the
  HTTP send.
  """
  @callback wrap_send_event(args(), opts()) :: Inngest.Client.send_result()

  @doc """
  Wraps an incoming function request.

  `args.request` contains the framework request information when available and
  `args.next` returns the generated SDK response.
  """
  @callback wrap_request(args(), opts()) :: term()

  @doc """
  Mutates the function context, input, and memoized step map for this request.

  Return the updated args map with `:ctx`, `:input`, and `:steps` keys.
  """
  @callback transform_function_input(args(), opts()) :: args() | {:ok, args()}

  @doc """
  Runs once when memoization replay has ended for this request.

  In this SDK this hook fires after function input transformation, before fresh
  function code starts.
  """
  @callback on_memoization_end(args(), opts()) :: term()

  @doc """
  Runs before fresh function code begins for this request.
  """
  @callback on_run_start(args(), opts()) :: term()

  @doc """
  Runs after function code completes successfully.
  """
  @callback on_run_complete(args(), opts()) :: term()

  @doc """
  Runs after function code returns or raises an error.
  """
  @callback on_run_error(args(), opts()) :: term()

  @doc """
  Wraps the user function handler.

  `args.next` returns the function result tuple, such as `{:ok, value}` or
  `{:error, reason}`.
  """
  @callback wrap_function_handler(args(), opts()) :: result()

  @doc """
  Mutates step metadata and arguments before the step ID is hashed.

  Return the updated args map with `:step_id`, `:step_type`, `:input`, and
  `:options` keys where applicable.
  """
  @callback transform_step_input(args(), opts()) :: args() | {:ok, args()}

  @doc """
  Wraps a step request.

  This hook runs for both fresh and memoized step values. `args.next` returns
  the step value visible to user code.
  """
  @callback wrap_step(args(), opts()) :: term()

  @doc """
  Runs before a fresh step handler executes.
  """
  @callback on_step_start(args(), opts()) :: term()

  @doc """
  Runs after a fresh step handler completes successfully.
  """
  @callback on_step_complete(args(), opts()) :: term()

  @doc """
  Runs after a fresh step handler raises.
  """
  @callback on_step_error(args(), opts()) :: term()

  @doc """
  Wraps a fresh step handler.

  `args.next` executes the step body and returns its output. This hook does not
  run for memoized step values.
  """
  @callback wrap_step_handler(args(), opts()) :: term()

  @optional_callbacks on_register: 2,
                      transform_send_event: 2,
                      wrap_send_event: 2,
                      wrap_request: 2,
                      transform_function_input: 2,
                      on_memoization_end: 2,
                      on_run_start: 2,
                      on_run_complete: 2,
                      on_run_error: 2,
                      wrap_function_handler: 2,
                      transform_step_input: 2,
                      wrap_step: 2,
                      on_step_start: 2,
                      on_step_complete: 2,
                      on_step_error: 2,
                      wrap_step_handler: 2

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
  @spec run_on_register([normalized_entry()], args()) :: :ok
  def run_on_register(middleware, args), do: run_side_effect(middleware, :on_register, args)

  @doc false
  @spec run_transform_send_event([normalized_entry()], [Inngest.Event.t()], term()) ::
          [Inngest.Event.t()]
  def run_transform_send_event(middleware, events, context) do
    args =
      middleware
      |> run_transform(:transform_send_event, %{events: events, context: context})

    args.events |> List.wrap()
  end

  @doc false
  @spec run_wrap_send_event([normalized_entry()], args(), fun()) :: Inngest.Client.send_result()
  def run_wrap_send_event(middleware, args, next) do
    run_wrap(middleware, :wrap_send_event, args, next)
  end

  @doc false
  @spec run_wrap_request([normalized_entry()], args(), fun()) :: term()
  def run_wrap_request(middleware, args, next) do
    run_wrap(middleware, :wrap_request, args, next)
  end

  @doc false
  @spec run_transform_function_input([normalized_entry()], args()) ::
          {Context.t(), Input.t(), map()}
  def run_transform_function_input(middleware, args) do
    args = run_transform(middleware, :transform_function_input, args)
    {args.ctx, args.input, Map.get(args, :steps, %{})}
  end

  @doc false
  @spec run_on_memoization_end([normalized_entry()], args()) :: :ok
  def run_on_memoization_end(middleware, args),
    do: run_side_effect(middleware, :on_memoization_end, args)

  @doc false
  @spec run_on_run_start([normalized_entry()], args()) :: :ok
  def run_on_run_start(middleware, args), do: run_side_effect(middleware, :on_run_start, args)

  @doc false
  @spec run_on_run_complete([normalized_entry()], args()) :: :ok
  def run_on_run_complete(middleware, args),
    do: run_side_effect(middleware, :on_run_complete, args)

  @doc false
  @spec run_on_run_error([normalized_entry()], args()) :: :ok
  def run_on_run_error(middleware, args), do: run_side_effect(middleware, :on_run_error, args)

  @doc false
  @spec run_wrap_function_handler([normalized_entry()], args(), fun()) :: result()
  def run_wrap_function_handler(middleware, args, next) do
    run_wrap(middleware, :wrap_function_handler, args, next)
  end

  @doc false
  @spec run_transform_step_input([normalized_entry()], args()) :: args()
  def run_transform_step_input(middleware, args) do
    run_transform(middleware, :transform_step_input, args)
  end

  @doc false
  @spec run_wrap_step([normalized_entry()], args(), fun()) :: term()
  def run_wrap_step(middleware, args, next) do
    run_wrap(middleware, :wrap_step, args, next)
  end

  @doc false
  @spec run_on_step_start([normalized_entry()], args()) :: :ok
  def run_on_step_start(middleware, args), do: run_side_effect(middleware, :on_step_start, args)

  @doc false
  @spec run_on_step_complete([normalized_entry()], args()) :: :ok
  def run_on_step_complete(middleware, args),
    do: run_side_effect(middleware, :on_step_complete, args)

  @doc false
  @spec run_on_step_error([normalized_entry()], args()) :: :ok
  def run_on_step_error(middleware, args), do: run_side_effect(middleware, :on_step_error, args)

  @doc false
  @spec run_wrap_step_handler([normalized_entry()], args(), fun()) :: term()
  def run_wrap_step_handler(middleware, args, next) do
    run_wrap(middleware, :wrap_step_handler, args, next)
  end

  defp normalize_entry(module) when is_atom(module), do: {module, []}
  defp normalize_entry({module, opts}) when is_atom(module) and is_list(opts), do: {module, opts}

  defp normalize_entry(entry) do
    raise ArgumentError, "invalid Inngest middleware entry: #{inspect(entry)}"
  end

  defp run_transform(middleware, callback, args) do
    Enum.reduce(middleware, args, fn {module, opts}, acc ->
      if callback?(module, callback, 2) do
        module
        |> apply(callback, [acc, opts])
        |> unwrap_transform(callback)
      else
        acc
      end
    end)
  end

  defp run_wrap(middleware, callback, args, next) do
    middleware
    |> Enum.reverse()
    |> Enum.reduce(next, &wrap_callback(&1, &2, callback, args))
    |> then(& &1.())
  end

  defp wrap_callback({module, opts}, next, callback, args) do
    if callback?(module, callback, 2) do
      fn -> apply(module, callback, [Map.put(args, :next, next), opts]) end
    else
      next
    end
  end

  defp run_side_effect(middleware, callback, args) do
    Enum.each(middleware, fn {module, opts} ->
      if callback?(module, callback, 2) do
        apply(module, callback, [args, opts])
      end
    end)

    :ok
  end

  defp callback?(module, callback, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, callback, arity)
  end

  defp unwrap_transform({:ok, value}, _callback), do: value
  defp unwrap_transform(value, _callback) when is_map(value), do: value

  defp unwrap_transform(value, callback) do
    raise ArgumentError,
          "#{inspect(callback)} middleware callback returned invalid value: #{inspect(value)}"
  end
end
