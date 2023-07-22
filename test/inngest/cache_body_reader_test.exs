defmodule Inngest.CacheBodyReaderTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Inngest.CacheBodyReader

  describe "read_body/2" do
    @body %{"hello" => "world"}

    setup do
      conn =
        conn(:post, "/api/inngest", Jason.encode!(@body))
        |> Plug.Conn.put_req_header("content-type", "application/json")

      %{conn: conn}
    end

    test "should cache body in assigns", %{conn: conn} do
      assert {:ok, _body,
              %{
                private: %{raw_body: [raw]}
              }} = CacheBodyReader.read_body(conn, [])

      assert {:ok, body} = Jason.decode(raw)
      assert body == @body
    end
  end
end
