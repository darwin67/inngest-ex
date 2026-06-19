defmodule Inngest.Router.InvokeTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-auth-test", name: "Invoke Auth Test"}
  @trigger %Trigger{event: "test/router.invoke"}

  @impl true
  def exec(_ctx, _input), do: {:ok, %{"ok" => true}}
end

defmodule Inngest.Router.InvokeContextTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-context-test", name: "Invoke Context Test"}
  @trigger %Trigger{event: "test/router.invoke.context"}

  @impl true
  def exec(ctx, input) do
    send(Application.fetch_env!(:inngest, :invoke_test_pid), {:invoke, ctx, input})
    {:ok, %{"ok" => true}}
  end
end

defmodule Inngest.Router.InvokeStepErrorTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-step-error-test", name: "Invoke Step Error Test"}
  @trigger %Trigger{event: "test/router.invoke.step_error"}

  @impl true
  def exec(ctx, %{step: step}) do
    step.run(ctx, "failed-step", fn -> "ok" end)
  end
end

defmodule Inngest.Router.InvokeNoStepTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "invoke-no-step-test", name: "Invoke No Step Test"}
  @trigger %Trigger{event: "test/router.invoke.no_step"}

  @impl true
  def exec(_ctx, _input), do: {:ok, "done"}
end

defmodule Inngest.Router.InvokeTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Inngest.{Config, Headers, Signature}
  alias Inngest.Router.Invoke

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @fallback_signing_key "signkey-fallback-746573742d66616c6c6261636b2d7369676e696e672d6b657921"

  @env_vars ~w(INNGEST_API_BASE_URL INNGEST_DEV INNGEST_SIGNING_KEY INNGEST_SIGNING_KEY_FALLBACK)
  @config_keys ~w(app_name env signing_key signing_key_fallback invoke_test_pid)a

  setup do
    env = Map.new(@env_vars, &{&1, System.get_env(&1)})
    config = Map.new(@config_keys, &{&1, Application.fetch_env(:inngest, &1)})
    tesla_adapter = Application.fetch_env(:tesla, :adapter)

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@config_keys, &Application.delete_env(:inngest, &1))

    on_exit(fn ->
      Enum.each(env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      Enum.each(config, fn
        {key, {:ok, value}} -> Application.put_env(:inngest, key, value)
        {key, :error} -> Application.delete_env(:inngest, key)
      end)

      case tesla_adapter do
        {:ok, adapter} -> Application.put_env(:tesla, :adapter, adapter)
        :error -> Application.delete_env(:tesla, :adapter)
      end
    end)
  end

  describe "call/2 signature verification" do
    test "accepts a cloud mode request signed with the fallback key" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)
      System.put_env("INNGEST_SIGNING_KEY_FALLBACK", @fallback_signing_key)

      {body, params} = invoke_body()

      signature =
        System.os_time(:second)
        |> Integer.to_string()
        |> Signature.sign(@fallback_signing_key, body)

      conn =
        body
        |> invoke_conn(params)
        |> Plug.Conn.put_req_header(Headers.signature(), signature)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"ok" => true}
      assert Plug.Conn.get_resp_header(conn, Headers.sdk_version()) == [Config.sdk_version()]
      assert Plug.Conn.get_resp_header(conn, Headers.req_version()) == [Config.req_version()]
    end

    test "rejects an unsigned cloud mode request" do
      System.put_env("INNGEST_SIGNING_KEY", @signing_key)

      {body, params} = invoke_body()

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 400
      assert Plug.Conn.get_resp_header(conn, Headers.no_retry()) == ["true"]
    end

    test "accepts an unsigned dev mode request" do
      System.put_env("INNGEST_DEV", "1")

      {body, params} = invoke_body()

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"ok" => true}
    end
  end

  describe "call/2 request payload" do
    test "exposes function input and context from the call request" do
      Application.put_env(:inngest, :invoke_test_pid, self())
      System.put_env("INNGEST_DEV", "1")

      event = %{"name" => "test/router.invoke.context", "data" => %{"n" => 1}}

      {body, params} =
        invoke_body(
          event: event,
          events: [event],
          ctx: %{
            "run_id" => "run-context",
            "attempt" => 2,
            "use_api" => false,
            "disable_immediate_execution" => true,
            "stack" => %{"current" => 1, "stack" => ["memoized-step"]}
          },
          fn_id: Inngest.Router.InvokeContextTestFn.slug()
        )

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeContextTestFn]})

      assert conn.status == 200

      assert_receive {:invoke, ctx, input}

      assert ctx.run_id == "run-context"
      assert ctx.attempt == 2
      assert ctx.disable_immediate_execution == true
      assert ctx.stack == %{"current" => 1, "stack" => ["memoized-step"]}

      assert input.run_id == "run-context"
      assert input.attempt == 2
      assert input.event.name == "test/router.invoke.context"
      assert input.event.data == %{"n" => 1}
      assert Enum.map(input.events, & &1.name) == ["test/router.invoke.context"]
    end

    test "retrieves full events and steps when ctx.use_api is true" do
      Application.put_env(:inngest, :invoke_test_pid, self())
      Application.put_env(:tesla, :adapter, Tesla.Mock)
      System.put_env("INNGEST_DEV", "1")
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")

      fetched_event = %{"name" => "test/router.invoke.context", "data" => %{"fetched" => true}}
      fetched_steps = %{"step-hash" => %{"data" => "memoized"}}

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.example/v0/runs/run-full/actions"} ->
          %Tesla.Env{status: 200, body: fetched_steps}

        %{method: :get, url: "https://api.example/v0/runs/run-full/batch"} ->
          %Tesla.Env{status: 200, body: [fetched_event]}
      end)

      trimmed_event = %{"name" => "test/router.trimmed", "data" => %{}}

      {body, params} =
        invoke_body(
          event: trimmed_event,
          events: [trimmed_event],
          ctx: %{"run_id" => "run-full", "attempt" => 0, "use_api" => true},
          fn_id: Inngest.Router.InvokeContextTestFn.slug(),
          steps: %{}
        )

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeContextTestFn]})

      assert conn.status == 200
      assert_receive {:invoke, ctx, input}
      assert ctx.steps == fetched_steps
      assert input.event.name == "test/router.invoke.context"
      assert [%{name: "test/router.invoke.context"}] = input.events
    end

    test "returns 500 when a required full payload fetch fails" do
      Application.put_env(:tesla, :adapter, Tesla.Mock)
      System.put_env("INNGEST_DEV", "1")
      System.put_env("INNGEST_API_BASE_URL", "https://api.example")

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.example/v0/runs/run-fetch-fail/actions"} ->
          %Tesla.Env{status: 500, body: %{"error" => "boom"}}

        %{method: :get, url: "https://api.example/v0/runs/run-fetch-fail/batch"} ->
          %Tesla.Env{status: 200, body: []}
      end)

      {body, params} =
        invoke_body(
          ctx: %{"run_id" => "run-fetch-fail", "attempt" => 0, "use_api" => true},
          fn_id: Inngest.Router.InvokeContextTestFn.slug()
        )

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeContextTestFn]})

      assert conn.status == 500
    end

    test "returns 500 when fnId does not match a registered function" do
      System.put_env("INNGEST_DEV", "1")

      {body, params} = invoke_body(fn_id: "missing-fn")

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeTestFn]})

      assert conn.status == 500
    end

    test "returns memoized step errors as non-retriable function errors" do
      System.put_env("INNGEST_DEV", "1")

      step_id = hash("failed-step")

      {body, params} =
        invoke_body(
          fn_id: Inngest.Router.InvokeStepErrorTestFn.slug(),
          steps: %{
            step_id => %{
              "error" => %{"name" => "RuntimeError", "message" => "memoized boom"}
            }
          }
        )

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeStepErrorTestFn]})

      assert conn.status == 400
      assert Plug.Conn.get_resp_header(conn, Headers.no_retry()) == ["true"]

      assert %{"name" => "RuntimeError", "message" => "memoized boom"} =
               Jason.decode!(conn.resp_body)
    end

    test "returns StepNotFound when targeted execution cannot reach the requested step" do
      System.put_env("INNGEST_DEV", "1")

      target_step_id = hash("missing-step")

      {body, params} =
        invoke_body(
          fn_id: Inngest.Router.InvokeStepErrorTestFn.slug(),
          step_id: target_step_id
        )

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeStepErrorTestFn]})

      assert conn.status == 206
      assert [%{"id" => ^target_step_id, "op" => "StepNotFound"}] = Jason.decode!(conn.resp_body)
    end

    test "returns StepNotFound when targeted traversal completes without finding the step" do
      System.put_env("INNGEST_DEV", "1")

      target_step_id = hash("missing-step")

      {body, params} =
        invoke_body(
          fn_id: Inngest.Router.InvokeNoStepTestFn.slug(),
          step_id: target_step_id
        )

      conn =
        body
        |> invoke_conn(params)
        |> Invoke.call(%{funcs: [Inngest.Router.InvokeNoStepTestFn]})

      assert conn.status == 206
      assert [%{"id" => ^target_step_id, "op" => "StepNotFound"}] = Jason.decode!(conn.resp_body)
    end
  end

  defp invoke_body(opts \\ []) do
    event = Keyword.get(opts, :event, %{"name" => "test/router.invoke", "data" => %{}})
    events = Keyword.get(opts, :events, [event])
    ctx = Keyword.get(opts, :ctx, %{"run_id" => "run-1", "attempt" => 0, "use_api" => false})
    fn_id = Keyword.get(opts, :fn_id, Inngest.Router.InvokeTestFn.slug())
    steps = Keyword.get(opts, :steps, %{})
    step_id = Keyword.get(opts, :step_id)

    params =
      %{
        "event" => event,
        "events" => events,
        "ctx" => ctx,
        "fnId" => fn_id,
        "steps" => steps
      }
      |> maybe_put("stepId", step_id)

    {Jason.encode!(params), params}
  end

  defp invoke_conn(body, params) do
    :post
    |> conn("/api/inngest", body)
    |> Plug.Conn.put_private(:raw_body, [body])
    |> Map.put(:params, params)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp hash(id), do: :crypto.hash(:sha, id) |> Base.encode16()
end
