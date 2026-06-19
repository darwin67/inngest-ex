defmodule Inngest.MiddlewareTest.ClientMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def on_register(args, _opts) do
    send(test_pid(), {:hook, :client, :on_register, args.function})
  end

  @impl true
  def transform_function_input(%{ctx: ctx, input: input} = args, _opts) do
    send(test_pid(), {:hook, :client, :transform_function_input})

    ctx = put_in(ctx.data[:client_transform_function_input], true)
    input = put_in(input.event.data, Map.put(input.event.data, "client", "input"))

    %{args | ctx: ctx, input: input}
  end

  @impl true
  def on_memoization_end(_args, _opts) do
    send(test_pid(), {:hook, :client, :on_memoization_end})
  end

  @impl true
  def on_run_start(_args, _opts) do
    send(test_pid(), {:hook, :client, :on_run_start})
  end

  @impl true
  def wrap_function_handler(%{next: next}, _opts) do
    send(test_pid(), {:hook, :client, :wrap_function_handler_before})

    case next.() do
      {:ok, output} ->
        send(test_pid(), {:hook, :client, :wrap_function_handler_after})
        {:ok, Map.put(output, "client_wrapper", true)}

      result ->
        result
    end
  end

  @impl true
  def on_run_complete(_args, _opts) do
    send(test_pid(), {:hook, :client, :on_run_complete})
  end

  @impl true
  def wrap_request(%{next: next}, _opts) do
    send(test_pid(), {:hook, :client, :wrap_request_before})
    response = next.()
    send(test_pid(), {:hook, :client, :wrap_request_after})
    put_response_body(response, "client_response", true)
  end

  defp put_response_body(response, key, value) do
    body =
      response.body
      |> Jason.decode!()
      |> Map.put(key, value)
      |> Jason.encode!()

    %{response | body: body}
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.FunctionMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def on_register(args, _opts) do
    send(test_pid(), {:hook, :function, :on_register, args.function})
  end

  @impl true
  def transform_function_input(%{ctx: ctx, input: input} = args, _opts) do
    send(test_pid(), {:hook, :function, :transform_function_input})

    ctx = put_in(ctx.data[:function_transform_function_input], true)
    input = put_in(input.event.data, Map.put(input.event.data, "function", "input"))

    %{args | ctx: ctx, input: input}
  end

  @impl true
  def on_memoization_end(_args, _opts) do
    send(test_pid(), {:hook, :function, :on_memoization_end})
  end

  @impl true
  def on_run_start(_args, _opts) do
    send(test_pid(), {:hook, :function, :on_run_start})
  end

  @impl true
  def wrap_function_handler(%{next: next}, _opts) do
    send(test_pid(), {:hook, :function, :wrap_function_handler_before})

    case next.() do
      {:ok, output} ->
        send(test_pid(), {:hook, :function, :wrap_function_handler_after})
        {:ok, Map.put(output, "function_wrapper", true)}

      result ->
        result
    end
  end

  @impl true
  def on_run_complete(_args, _opts) do
    send(test_pid(), {:hook, :function, :on_run_complete})
  end

  @impl true
  def wrap_request(%{next: next}, _opts) do
    send(test_pid(), {:hook, :function, :wrap_request_before})
    response = next.()
    send(test_pid(), {:hook, :function, :wrap_request_after})
    put_response_body(response, "function_response", true)
  end

  defp put_response_body(response, key, value) do
    body =
      response.body
      |> Jason.decode!()
      |> Map.put(key, value)
      |> Jason.encode!()

    %{response | body: body}
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.EventMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def transform_send_event(%{events: events, context: context} = args, opts) do
    send(test_pid(), {:event_hook, :transform_send_event, context.ctx.__struct__})
    tag = Keyword.fetch!(opts, :tag)

    events =
      Enum.map(events, fn event ->
        update_in(event.data, &Map.put(&1, :middleware, tag))
      end)

    %{args | events: events}
  end

  @impl true
  def wrap_send_event(%{next: next}, _opts) do
    send(test_pid(), {:event_hook, :wrap_send_event_before})

    case next.() do
      {:ok, response} ->
        send(test_pid(), {:event_hook, :wrap_send_event_after})
        {:ok, Map.put(response, "middleware", "wrapped")}

      result ->
        result
    end
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.StepMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def transform_step_input(args, _opts) do
    send(test_pid(), {:step_hook, :transform_step_input, args.step_type})
    args
  end

  @impl true
  def wrap_step(%{step_info: %{memoized: memoized}, next: next}, _opts) do
    send(test_pid(), {:step_hook, :wrap_step_before, memoized})

    value = next.()

    send(test_pid(), {:step_hook, :wrap_step_after, memoized})

    if is_map(value) do
      Map.put(value, "wrap_step", memoized)
    else
      value
    end
  end

  @impl true
  def on_step_start(args, _opts) do
    send(test_pid(), {:step_hook, :on_step_start, args.step_info.step_type})
  end

  @impl true
  def wrap_step_handler(%{next: next}, _opts) do
    send(test_pid(), {:step_hook, :wrap_step_handler_before})

    value = next.()

    send(test_pid(), {:step_hook, :wrap_step_handler_after})
    value
  end

  @impl true
  def on_step_complete(args, _opts) do
    send(test_pid(), {:step_hook, :on_step_complete, args.step_info.step_type})
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.Function do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{
    id: "middleware-test",
    name: "Middleware Test",
    middleware: [Inngest.MiddlewareTest.FunctionMiddleware]
  }
  @trigger %Trigger{event: "test/middleware"}

  @impl true
  def exec(ctx, input) do
    send(Application.fetch_env!(:inngest, :middleware_test_pid), {
      :exec,
      ctx.data,
      ctx.request.request_path,
      input.event.data
    })

    {:ok, input.event.data}
  end
end

defmodule Inngest.MiddlewareTest.Client do
  @moduledoc false

  use Inngest.Client,
    id: "middleware-app",
    funcs: [Inngest.MiddlewareTest.Function],
    middleware: [Inngest.MiddlewareTest.ClientMiddleware]
end

defmodule Inngest.MiddlewareTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Inngest.Function.Context
  alias Inngest.Router.Invoke
  alias Inngest.StepTool

  setup do
    env = System.get_env("INNGEST_DEV")
    app_pid = Application.fetch_env(:inngest, :middleware_test_pid)
    adapter = Application.fetch_env(:tesla, :adapter)

    Application.put_env(:inngest, :middleware_test_pid, self())
    System.put_env("INNGEST_DEV", "1")

    on_exit(fn ->
      case env do
        nil -> System.delete_env("INNGEST_DEV")
        value -> System.put_env("INNGEST_DEV", value)
      end

      case app_pid do
        {:ok, pid} -> Application.put_env(:inngest, :middleware_test_pid, pid)
        :error -> Application.delete_env(:inngest, :middleware_test_pid)
      end

      case adapter do
        {:ok, value} -> Application.put_env(:tesla, :adapter, value)
        :error -> Application.delete_env(:tesla, :adapter)
      end
    end)
  end

  test "runs TS-style client middleware before function middleware" do
    {body, params} = invoke_body()

    conn =
      body
      |> invoke_conn(params)
      |> Invoke.call(%{client: Inngest.MiddlewareTest.Client})

    assert conn.status == 200

    assert_receive {:hook, :client, :on_register, nil}
    assert_receive {:hook, :function, :on_register, Inngest.MiddlewareTest.Function}
    assert_receive {:hook, :client, :wrap_request_before}
    assert_receive {:hook, :function, :wrap_request_before}
    assert_receive {:hook, :client, :transform_function_input}
    assert_receive {:hook, :function, :transform_function_input}
    assert_receive {:hook, :client, :on_memoization_end}
    assert_receive {:hook, :function, :on_memoization_end}
    assert_receive {:hook, :client, :on_run_start}
    assert_receive {:hook, :function, :on_run_start}
    assert_receive {:hook, :client, :wrap_function_handler_before}
    assert_receive {:hook, :function, :wrap_function_handler_before}

    assert_receive {:exec, ctx_data, "/api/inngest", input_data}

    assert ctx_data == %{
             client_transform_function_input: true,
             function_transform_function_input: true
           }

    assert input_data == %{"client" => "input", "function" => "input"}

    assert_receive {:hook, :function, :wrap_function_handler_after}
    assert_receive {:hook, :client, :wrap_function_handler_after}
    assert_receive {:hook, :client, :on_run_complete}
    assert_receive {:hook, :function, :on_run_complete}
    assert_receive {:hook, :function, :wrap_request_after}
    assert_receive {:hook, :client, :wrap_request_after}

    assert Jason.decode!(conn.resp_body) == %{
             "client" => "input",
             "client_response" => true,
             "client_wrapper" => true,
             "function" => "input",
             "function_response" => true,
             "function_wrapper" => true
           }
  end

  test "function modules expose normalized middleware entries" do
    assert Inngest.MiddlewareTest.Function.middleware() == [
             {Inngest.MiddlewareTest.FunctionMiddleware, []}
           ]
  end

  test "wrap_step mutates memoized step data before user code sees it" do
    ctx =
      ctx(
        steps: %{hash("first") => %{"data" => %{"value" => 1}}},
        middleware: [{Inngest.MiddlewareTest.StepMiddleware, []}]
      )

    assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end) == %{
             "value" => 1,
             "wrap_step" => true
           }

    assert_receive {:step_hook, :transform_step_input, "run"}
    assert_receive {:step_hook, :wrap_step_before, true}
    assert_receive {:step_hook, :wrap_step_after, true}
  end

  test "fresh run steps use step lifecycle hooks" do
    assert %Inngest.Function.GeneratorOpCode{
             data: %{"ok" => true},
             op: "StepRun"
           } =
             catch_throw(
               StepTool.run(
                 ctx(middleware: [{Inngest.MiddlewareTest.StepMiddleware, []}]),
                 "first",
                 fn -> %{"ok" => true} end
               )
             )

    assert_receive {:step_hook, :transform_step_input, "run"}
    assert_receive {:step_hook, :wrap_step_before, false}
    assert_receive {:step_hook, :on_step_start, "run"}
    assert_receive {:step_hook, :wrap_step_handler_before}
    assert_receive {:step_hook, :wrap_step_handler_after}
    assert_receive {:step_hook, :on_step_complete, "run"}
    assert_receive {:step_hook, :wrap_step_after, false}
  end

  test "step send_event uses active invocation middleware" do
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    client =
      Inngest.Client.new(
        id: "step-middleware-client",
        event_url: "https://events.example",
        event_key: "event-key"
      )

    Tesla.Mock.mock(fn %{method: :post, body: body} ->
      [event] = Jason.decode!(body)
      assert event["data"] == %{"middleware" => "step"}

      %Tesla.Env{status: 200, body: %{"ids" => ["event-id"], "status" => 200}}
    end)

    assert %Inngest.Function.GeneratorOpCode{
             data: %{event_ids: ["event-id"]},
             op: "StepRun"
           } =
             catch_throw(
               StepTool.send_event(
                 ctx(
                   client: client,
                   middleware: [{Inngest.MiddlewareTest.EventMiddleware, tag: "step"}]
                 ),
                 "send",
                 %Inngest.Event{name: "test/step.middleware"}
               )
             )

    assert_receive {:event_hook, :transform_send_event, Context}
    assert_receive {:event_hook, :wrap_send_event_before}
    assert_receive {:event_hook, :wrap_send_event_after}
  end

  defp invoke_body do
    params = %{
      "event" => %{"name" => "test/middleware", "data" => %{}},
      "events" => [%{"name" => "test/middleware", "data" => %{}}],
      "ctx" => %{"run_id" => "run-1", "attempt" => 0, "use_api" => false},
      "fnId" => Inngest.MiddlewareTest.Function.slug(Inngest.MiddlewareTest.Client.client().id),
      "steps" => %{}
    }

    {Jason.encode!(params), params}
  end

  defp invoke_conn(body, params) do
    :post
    |> conn("/api/inngest", body)
    |> Plug.Conn.put_private(:raw_body, [body])
    |> Map.put(:params, params)
  end

  defp ctx(attrs) do
    defaults = %{
      attempt: 0,
      run_id: "run-1",
      client: nil,
      request: nil,
      data: %{},
      middleware: [],
      disable_immediate_execution: false,
      stack: nil,
      target_step_id: "step",
      steps: %{},
      index: :ets.new(:index, [:set, :private])
    }

    struct!(Context, Map.merge(defaults, Map.new(attrs)))
  end

  defp hash(id), do: :crypto.hash(:sha, id) |> Base.encode16()
end
