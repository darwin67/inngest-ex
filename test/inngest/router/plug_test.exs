defmodule Inngest.Router.PlugTestFn do
  @moduledoc false

  use Inngest.Function

  @func %FnOpts{id: "plug-test", name: "Plug Test"}
  @trigger %Trigger{event: "test/router.plug"}

  @impl true
  def exec(_ctx, input) do
    send(Application.fetch_env!(:inngest, :plug_router_test_pid), {:input, input})
    {:ok, %{"ok" => true}}
  end
end

defmodule Inngest.Router.PlugTestClient do
  @moduledoc false

  use Inngest.Client,
    id: "plug-router-app",
    funcs: [Inngest.Router.PlugTestFn],
    mode: :dev
end

defmodule Inngest.Router.PlugTestRouter do
  @moduledoc false

  use Plug.Router
  use Inngest.Router, :plug

  plug(:match)
  plug(:dispatch)

  inngest("/api/inngest", client: Inngest.Router.PlugTestClient)
end

defmodule Inngest.Router.PlugTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  setup do
    config = Application.fetch_env(:inngest, :plug_router_test_pid)
    Application.put_env(:inngest, :plug_router_test_pid, self())

    on_exit(fn ->
      case config do
        {:ok, value} -> Application.put_env(:inngest, :plug_router_test_pid, value)
        :error -> Application.delete_env(:inngest, :plug_router_test_pid)
      end
    end)
  end

  test "parses invoke bodies with the cached body reader by default" do
    body =
      Jason.encode!(%{
        "event" => %{"name" => "test/router.plug", "data" => %{"hello" => "world"}},
        "events" => [%{"name" => "test/router.plug", "data" => %{"hello" => "world"}}],
        "ctx" => %{"run_id" => "run-1", "attempt" => 0, "use_api" => false},
        "fnId" => Inngest.Router.PlugTestFn.slug(Inngest.Router.PlugTestClient.client().id),
        "steps" => %{}
      })

    conn =
      :post
      |> conn("/api/inngest", body)
      |> put_req_header("content-type", "application/json")
      |> Inngest.Router.PlugTestRouter.call([])

    assert conn.status == 200
    assert Inngest.CacheBodyReader.read_cached_body(conn) == body
    assert_receive {:input, %{event: %{data: %{"hello" => "world"}}}}
  end
end
