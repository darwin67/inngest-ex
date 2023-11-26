defmodule Inngest.FnOptsTest do
  use ExUnit.Case, async: true

  alias Inngest.FnOpts

  describe "validate_debounce/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "FooBar",
      debounce: %{
        period: "5s"
      }
    }

    @config %{}

    test "should succeed with valid config" do
      assert %{debounce: _} = FnOpts.validate_debounce(@fn_opts, @config)
    end

    ## Invalid configs
    test "should raise when period is missing" do
      opts = drop_at(@fn_opts, [:debounce, :period])

      assert_raise Inngest.InvalidDebounceConfigError, fn ->
        FnOpts.validate_debounce(opts, @config)
      end
    end

    test "should raise with invalid period" do
      opts = update_at(@fn_opts, [:debounce, :period], "yolo")

      assert_raise Inngest.InvalidDebounceConfigError, fn ->
        FnOpts.validate_debounce(opts, @config)
      end
    end

    test "should raise with period longer than 7 days" do
      opts = update_at(@fn_opts, [:debounce, :period], "8d")

      assert_raise Inngest.InvalidDebounceConfigError, fn ->
        FnOpts.validate_debounce(opts, @config)
      end
    end

    # helper function to remove nested fields from a struct
    defp drop_at(struct, path) do
      access = Enum.map(path, fn f -> Access.key!(f) end)
      pop_in(struct, access) |> elem(1)
    end

    defp update_at(struct, path, new_value) do
      access = Enum.map(path, fn f -> Access.key!(f) end)
      update_in(struct, access, fn _ -> new_value end)
    end
  end
end
