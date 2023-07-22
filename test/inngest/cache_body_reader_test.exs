defmodule Inngest.CacheBodyReaderTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Inngest.CacheBodyReader

  @body %{"hello" => "world"}

  setup do
    raw = Jason.encode!(@body)

    conn =
      conn(:post, "/api/inngest", raw)
      |> Plug.Conn.put_req_header("content-type", "application/json")

    %{conn: conn, raw: raw}
  end

  describe "read_body/2" do
    test "should cache body in assigns", %{conn: conn} do
      assert {:ok, _body,
              %{
                private: %{raw_body: [raw]}
              }} = CacheBodyReader.read_body(conn, [])

      assert {:ok, body} = Jason.decode(raw)
      assert body == @body
    end
  end

  describe "read_cached_body/1" do
    @tag :skip
    test "should be able to read cached body", %{conn: conn, raw: raw} do
      assert {:ok, _body, conn} = CacheBodyReader.read_body(conn, [])
      assert raw == CacheBodyReader.read_cached_body(conn)
    end
  end
end
