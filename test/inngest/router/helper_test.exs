defmodule Inngest.Router.HelperTest do
  use ExUnit.Case, async: true

  alias Inngest.Router.Helper

  defmodule Client do
    use Inngest.Client,
      id: "helper-client",
      funcs: []
  end

  describe "require_client!/1" do
    test "returns opts when a client is present" do
      assert %{client: Client} = Helper.require_client!(%{client: Client})
    end

    test "raises when a client is missing" do
      assert_raise ArgumentError, "Inngest router requires :client", fn ->
        Helper.require_client!(%{funcs: []})
      end
    end
  end

  describe "client!/1" do
    test "resolves a client module into a runtime client struct" do
      assert %Inngest.Client{id: "helper-client"} = Helper.client!(%{client: Client})
    end

    test "returns an already-built runtime client struct" do
      client = Client.client()

      assert Helper.client!(%{client: client}) == client
    end
  end
end
