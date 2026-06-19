defmodule Inngest.MiddlewareTest.ClientLifecycleMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def transform_input(ctx, input, _opts) do
    send(test_pid(), {:hook, :client, :transform_input})

    ctx = put_in(ctx.data[:client_transform_input], true)
    input = put_in(input.event.data, Map.put(input.event.data, "client", "input"))

    {ctx, input}
  end

  @impl true
  def before_execution(ctx, input, _opts) do
    send(test_pid(), {:hook, :client, :before_execution})
    {put_in(ctx.data[:client_before_execution], true), input}
  end

  @impl true
  def after_execution(_ctx, _input, {:ok, output}, _opts) do
    send(test_pid(), {:hook, :client, :after_execution})
    {:ok, Map.put(output, "client_after", true)}
  end

  @impl true
  def transform_output(_ctx, _input, {:ok, output}, _opts) do
    send(test_pid(), {:hook, :client, :transform_output})
    {:ok, Map.put(output, "client_output", true)}
  end

  @impl true
  def before_response(_ctx, _input, response, _opts) do
    send(test_pid(), {:hook, :client, :before_response})

    body =
      response.body
      |> Jason.decode!()
      |> Map.put("client_response", true)
      |> Jason.encode!()

    %{response | body: body}
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.FunctionLifecycleMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def transform_input(ctx, input, _opts) do
    send(test_pid(), {:hook, :function, :transform_input})

    ctx = put_in(ctx.data[:function_transform_input], true)
    input = put_in(input.event.data, Map.put(input.event.data, "function", "input"))

    {ctx, input}
  end

  @impl true
  def before_execution(ctx, input, _opts) do
    send(test_pid(), {:hook, :function, :before_execution})
    {put_in(ctx.data[:function_before_execution], true), input}
  end

  @impl true
  def after_execution(_ctx, _input, {:ok, output}, _opts) do
    send(test_pid(), {:hook, :function, :after_execution})
    {:ok, Map.put(output, "function_after", true)}
  end

  @impl true
  def transform_output(_ctx, _input, {:ok, output}, _opts) do
    send(test_pid(), {:hook, :function, :transform_output})
    {:ok, Map.put(output, "function_output", true)}
  end

  @impl true
  def before_response(_ctx, _input, response, _opts) do
    send(test_pid(), {:hook, :function, :before_response})

    body =
      response.body
      |> Jason.decode!()
      |> Map.put("function_response", true)
      |> Jason.encode!()

    %{response | body: body}
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.EventMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def before_send_events(events, context, opts) do
    send(test_pid(), {:event_hook, :before_send_events, context.__struct__})
    tag = Keyword.fetch!(opts, :tag)

    Enum.map(events, fn event ->
      update_in(event.data, &Map.put(&1, :middleware, tag))
    end)
  end

  @impl true
  def after_send_events({:ok, response}, _events, _context, opts) do
    send(test_pid(), {:event_hook, :after_send_events})
    {:ok, Map.put(response, "middleware", Keyword.fetch!(opts, :tag))}
  end

  defp test_pid, do: Application.fetch_env!(:inngest, :middleware_test_pid)
end

defmodule Inngest.MiddlewareTest.StepDataMiddleware do
  @moduledoc false
  @behaviour Inngest.Middleware

  @impl true
  def after_memoization(_ctx, _step_id, value, _opts) do
    Map.put(value, "after_memoization", true)
  end

  @impl true
  def transform_step_data(_ctx, _step_id, value, _opts) do
    Map.put(value, "transform_step_data", true)
  end
end

defmodule Inngest.MiddlewareTest.Function do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{
    id: "middleware-test",
    name: "Middleware Test",
    middleware: [Inngest.MiddlewareTest.FunctionLifecycleMiddleware]
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
    middleware: [Inngest.MiddlewareTest.ClientLifecycleMiddleware]
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

  test "runs client middleware before function middleware through function lifecycle hooks" do
    {body, params} = invoke_body()

    conn =
      body
      |> invoke_conn(params)
      |> Invoke.call(%{client: Inngest.MiddlewareTest.Client})

    assert conn.status == 200

    assert_receive {:hook, :client, :transform_input}
    assert_receive {:hook, :function, :transform_input}
    assert_receive {:hook, :client, :before_execution}
    assert_receive {:hook, :function, :before_execution}

    assert_receive {:exec, ctx_data, "/api/inngest", input_data}

    assert ctx_data == %{
             client_before_execution: true,
             client_transform_input: true,
             function_before_execution: true,
             function_transform_input: true
           }

    assert input_data == %{"client" => "input", "function" => "input"}

    assert_receive {:hook, :client, :after_execution}
    assert_receive {:hook, :function, :after_execution}
    assert_receive {:hook, :client, :transform_output}
    assert_receive {:hook, :function, :transform_output}
    assert_receive {:hook, :client, :before_response}
    assert_receive {:hook, :function, :before_response}

    assert Jason.decode!(conn.resp_body) == %{
             "client" => "input",
             "client_after" => true,
             "client_output" => true,
             "client_response" => true,
             "function" => "input",
             "function_after" => true,
             "function_output" => true,
             "function_response" => true
           }
  end

  test "function modules expose normalized middleware entries" do
    assert Inngest.MiddlewareTest.Function.middleware() == [
             {Inngest.MiddlewareTest.FunctionLifecycleMiddleware, []}
           ]
  end

  test "middleware can mutate memoized step data before user code sees it" do
    ctx =
      ctx(
        steps: %{hash("first") => %{"data" => %{"value" => 1}}},
        middleware: [{Inngest.MiddlewareTest.StepDataMiddleware, []}]
      )

    assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end) == %{
             "after_memoization" => true,
             "transform_step_data" => true,
             "value" => 1
           }
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

    assert_receive {:event_hook, :before_send_events, Context}
    assert_receive {:event_hook, :after_send_events}
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
