defmodule Inngest.StepToolTest do
  use ExUnit.Case, async: false

  alias Inngest.Function.GeneratorOpCode
  alias Inngest.StepTool
  alias Inngest.Test.HTTPClient, as: TestHTTPClient

  defmodule InvokeTarget do
    def slug(app_id), do: "#{app_id}-invoke-target"
    def slug(), do: "legacy-invoke-target"
  end

  defmodule StepOptionsMiddleware do
    @behaviour Inngest.Middleware

    @impl true
    def transform_step_input(%{options: options} = args, _opts) do
      %{args | options: Map.put(options, :keys, :atoms)}
    end
  end

  setup do
    http_client = Application.fetch_env(:inngest, :http_client)
    TestHTTPClient.reset!()

    on_exit(fn ->
      TestHTTPClient.reset!()

      case http_client do
        {:ok, adapter} -> Application.put_env(:inngest, :http_client, adapter)
        :error -> Application.delete_env(:inngest, :http_client)
      end
    end)
  end

  describe "run/3" do
    test "reports an immediately executed run step when allowed" do
      assert %GeneratorOpCode{
               id: id,
               op: "StepRun",
               data: %{"ok" => true},
               display_name: "first"
             } =
               catch_throw(StepTool.run(ctx(), "first", fn -> %{"ok" => true} end))

      assert id == hash("first")
    end

    test "plans a run step when immediate execution is disabled" do
      assert %GeneratorOpCode{
               id: id,
               op: "StepPlanned",
               data: nil,
               display_name: "first"
             } =
               catch_throw(
                 StepTool.run(ctx(disable_immediate_execution: true), "first", fn ->
                   flunk("step body should not run")
                 end)
               )

      assert id == hash("first")
    end

    test "unwraps memoized run step data" do
      ctx = ctx(steps: %{hash("first") => %{"data" => "memoized"}})

      assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end) ==
               "memoized"
    end

    test "returns fresh step results without changing map keys" do
      assert %GeneratorOpCode{
               data: %{foo: "bar"}
             } = catch_throw(StepTool.run(ctx(), "first", fn -> %{foo: "bar"} end))
    end

    test "returns memoized map data with string keys by default" do
      ctx = ctx(steps: %{hash("first") => %{"data" => %{"foo" => "bar"}}})

      assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end) ==
               %{"foo" => "bar"}
    end

    test "converts memoized map data keys to existing atoms when requested" do
      ctx =
        ctx(
          steps: %{
            hash("first") => %{
              "data" => %{
                "foo" => [%{"bar" => "baz"}],
                "string-key" => "kept"
              }
            }
          }
        )

      assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end, keys: :atoms) ==
               %{
                 :"string-key" => "kept",
                 foo: [%{bar: "baz"}]
               }
    end

    test "uses transformed options when replaying memoized step data" do
      ctx =
        ctx(
          middleware: [{StepOptionsMiddleware, []}],
          steps: %{hash("first") => %{"data" => %{"foo" => "bar"}}}
        )

      assert StepTool.run(ctx, "first", fn -> flunk("step body should not run") end) ==
               %{foo: "bar"}
    end

    test "raises a clear error when atom key conversion would create an atom" do
      unknown_key = "inngest_unknown_key_#{System.unique_integer([:positive])}"
      ctx = ctx(steps: %{hash("first") => %{"data" => %{unknown_key => "bar"}}})

      assert_raise Inngest.StepError, ~r/cannot convert memoized step key/, fn ->
        StepTool.run(ctx, "first", fn -> flunk("step body should not run") end, keys: :atoms)
      end
    end

    test "raises a step error for memoized run step errors" do
      error = %{"name" => "RuntimeError", "message" => "boom", "stack" => "stack"}
      ctx = ctx(steps: %{hash("first") => %{"error" => error}})

      assert_raise Inngest.StepError, "boom", fn ->
        StepTool.run(ctx, "first", fn -> flunk("step body should not run") end)
      end
    end

    test "raises a step error for unsupported legacy raw run step data" do
      ctx = ctx(steps: %{hash("first") => "legacy"})

      assert_raise Inngest.StepError, ~r/invalid memoized step data/, fn ->
        StepTool.run(ctx, "first", fn -> flunk("step body should not run") end)
      end
    end

    test "runs a targeted hashed step after memoized prior steps" do
      ctx =
        ctx(
          target_step_id: hash("second"),
          stack: %{"current" => 1, "stack" => [hash("first"), hash("second")]},
          steps: %{hash("first") => %{"data" => "memoized"}}
        )

      assert StepTool.run(ctx, "first", fn -> flunk("first step should be memoized") end) ==
               "memoized"

      assert %GeneratorOpCode{
               id: id,
               op: "StepRun",
               data: "target",
               display_name: "second"
             } = catch_throw(StepTool.run(ctx, "second", fn -> "target" end))

      assert id == hash("second")
    end

    test "returns StepNotFound instead of executing unrelated steps during targeted execution" do
      target_step_id = hash("second")

      assert %GeneratorOpCode{id: ^target_step_id, op: "StepNotFound"} =
               catch_throw(
                 StepTool.run(ctx(target_step_id: target_step_id), "first", fn ->
                   flunk("unrelated step body should not run")
                 end)
               )
    end

    test "reports step body failures as StepError" do
      assert %GeneratorOpCode{
               id: id,
               op: "StepError",
               error: %{name: "RuntimeError", message: "boom"},
               display_name: "first"
             } =
               catch_throw(
                 StepTool.run(ctx(), "first", fn ->
                   raise "boom"
                 end)
               )

      assert id == hash("first")
    end

    test "lets explicit non-retriable step body errors bubble" do
      assert_raise Inngest.NonRetriableError, "do not retry", fn ->
        StepTool.run(ctx(), "first", fn ->
          raise Inngest.NonRetriableError, message: "do not retry"
        end)
      end
    end

    test "encodes run step nil results as data null and omits internal fields" do
      opcode = catch_throw(StepTool.run(ctx(), "first", fn -> nil end))

      assert Jason.decode!(Jason.encode!(opcode)) == %{
               "id" => hash("first"),
               "op" => "StepRun",
               "displayName" => "first",
               "data" => nil
             }
    end
  end

  describe "sleep/3" do
    test "reports sleep duration in opts" do
      assert %GeneratorOpCode{
               id: id,
               op: "Sleep",
               opts: %{duration: "10s"},
               display_name: "wait"
             } = catch_throw(StepTool.sleep(ctx(), "wait", "10s"))

      assert id == hash("wait")
    end

    test "preserves nil memoized sleep values" do
      assert StepTool.sleep(ctx(steps: %{hash("wait") => nil}), "wait", "10s") == nil
    end
  end

  describe "invoke/3" do
    test "uses invocation client id for function module targets" do
      client = Inngest.Client.new(id: "step-client")

      assert %GeneratorOpCode{
               op: "InvokeFunction",
               opts: %{
                 function_id: "step-client-invoke-target",
                 payload: %{data: %{hello: "world"}, v: nil}
               }
             } =
               catch_throw(
                 StepTool.invoke(ctx(client: client), "call target", %{
                   function: InvokeTarget,
                   data: %{hello: "world"}
                 })
               )
    end
  end

  describe "send_event/3" do
    test "uses invocation client when available" do
      Application.put_env(:inngest, :http_client, TestHTTPClient)

      client =
        Inngest.Client.new(
          id: "step-client",
          event_url: "https://step-events.example",
          event_key: "step-key",
          env: "step-env"
        )

      TestHTTPClient.mock(fn %{method: :post, url: url, body: body, headers: headers} ->
        assert url == "https://step-events.example/e/step-key"
        [event] = body
        assert event.name == "test/step.send"
        assert event.data == %{ok: true}
        assert {Inngest.Headers.env(), "step-env"} in headers

        TestHTTPClient.response(200, %{"ids" => ["step-event-id"], "status" => 200})
      end)

      assert %GeneratorOpCode{
               op: "StepRun",
               data: %{event_ids: ["step-event-id"]},
               display_name: "Send test/step.send"
             } =
               catch_throw(
                 StepTool.send_event(ctx(client: client), "send", %Inngest.Event{
                   name: "test/step.send",
                   data: %{ok: true}
                 })
               )
    end
  end

  defp ctx(attrs \\ []) do
    defaults = %{
      attempt: 0,
      run_id: "run-1",
      client: nil,
      disable_immediate_execution: false,
      stack: nil,
      target_step_id: "step",
      steps: %{},
      index: :ets.new(:index, [:set, :private])
    }

    struct!(Inngest.Function.Context, Map.merge(defaults, Map.new(attrs)))
  end

  defp hash(id), do: :crypto.hash(:sha, id) |> Base.encode16()
end
