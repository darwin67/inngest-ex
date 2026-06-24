defmodule Inngest.CacheBodyReaderTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias Inngest.CacheBodyReader

  @body %{"hello" => "world"}

  setup do
    raw = Jason.encode!(@body)

    conn =
      conn(:post, "/api/inngest", raw)
      |> put_req_header("content-type", "application/json")

    %{conn: conn, raw: raw}
  end

  describe "read_body/2" do
    test "caches body in private data", %{conn: conn} do
      assert {:ok, _body,
              %{
                private: %{inngest_raw_body: [raw]}
              }} = CacheBodyReader.read_body(conn, [])

      assert {:ok, body} = Jason.decode(raw)
      assert body == @body
    end

    test "caches multi-read bodies in request order" do
      conn =
        conn(:post, "/api/inngest", "abcdef")
        |> put_req_header("content-type", "application/json")

      assert {:more, "abc", conn} = CacheBodyReader.read_body(conn, read_length: 3, length: 3)
      assert {:ok, "def", conn} = CacheBodyReader.read_body(conn, read_length: 3, length: 3)

      assert "abcdef" == CacheBodyReader.read_cached_body(conn)
    end
  end

  describe "read_body/3" do
    test "caches matching request paths", %{conn: conn, raw: raw} do
      assert {:ok, _body, conn} = CacheBodyReader.read_body(conn, [], paths: ["/api/inngest"])
      assert raw == CacheBodyReader.read_cached_body(conn)
    end

    test "caches matching request paths with trailing slashes", %{raw: raw} do
      conn =
        conn(:post, "/api/inngest/", raw)
        |> put_req_header("content-type", "application/json")

      assert {:ok, _body, conn} = CacheBodyReader.read_body(conn, [], paths: ["/api/inngest"])
      assert raw == CacheBodyReader.read_cached_body(conn)
    end

    test "skips caching unrelated request paths", %{raw: raw} do
      conn =
        conn(:post, "/api/users", raw)
        |> put_req_header("content-type", "application/json")

      assert {:ok, _body, conn} = CacheBodyReader.read_body(conn, [], paths: ["/api/inngest"])
      assert "" == CacheBodyReader.read_cached_body(conn)
    end
  end

  describe "read_cached_body/1" do
    test "should be able to read cached body", %{conn: conn, raw: raw} do
      assert {:ok, _body, conn} = CacheBodyReader.read_body(conn, [])
      assert raw == CacheBodyReader.read_cached_body(conn)
    end
  end
end
