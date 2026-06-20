defmodule Inngest.HTTPClient.FinchTest do
  use ExUnit.Case, async: false

  alias Inngest.Test.HTTPAdapterCase

  setup do
    finch_name = Module.concat(__MODULE__, Finch)
    start_supervised!({Finch, name: finch_name})
    port = HTTPAdapterCase.unused_port()
    start_supervised!(HTTPAdapterCase.server_child_spec(port))

    {:ok,
     adapter: Inngest.HTTPClient.Finch,
     adapter_opts: [name: finch_name],
     base_url: HTTPAdapterCase.base_url(port)}
  end

  test "encodes JSON requests and decodes JSON responses", ctx do
    assert {:ok, response} =
             ctx.adapter.request(HTTPAdapterCase.json_request(ctx.base_url, ctx.adapter_opts))

    assert response.status == 201
    assert response.body["body"] == %{"ok" => true}
    assert response.body["content_type"] == ["application/json"]
    assert response.body["header"] == ["yes"]
  end

  test "preserves non-JSON response bodies", ctx do
    assert {:ok, response} =
             ctx.adapter.request(HTTPAdapterCase.text_request(ctx.base_url, ctx.adapter_opts))

    assert response.status == 202
    assert response.body == "plain response"
  end

  test "executes final URLs with query strings", ctx do
    assert {:ok, response} =
             ctx.adapter.request(HTTPAdapterCase.query_request(ctx.base_url, ctx.adapter_opts))

    assert response.status == 200
    assert response.body == %{"a" => "1", "b" => "two"}
  end
end
