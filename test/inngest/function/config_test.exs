defmodule Inngest.FnOptsTest do
  use ExUnit.Case, async: true

  alias Inngest.FnOpts

  @config %{}

  # helper function to remove nested fields from a struct
  defp drop_at(struct, path) do
    access = Enum.map(path, fn f -> Access.key!(f) end)
    pop_in(struct, access) |> elem(1)
  end

  defp update_at(struct, path, new_value) do
    access = Enum.map(path, fn f -> Access.key!(f) end)
    update_in(struct, access, fn _ -> new_value end)
  end

  describe "validate_debounce/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "FooBar",
      debounce: %{
        period: "5s"
      }
    }

    test "should succeed with valid config" do
      assert %{debounce: %{period: "5s"}} = FnOpts.validate_debounce(@fn_opts, @config)
    end

    ##  configs
    test "should raise when period is missing" do
      opts = drop_at(@fn_opts, [:debounce, :period])

      assert_raise Inngest.DebounceConfigError,
                   "'period' must be set for debounce",
                   fn ->
                     FnOpts.validate_debounce(opts, @config)
                   end
    end

    test "should raise with invalid period" do
      opts = update_at(@fn_opts, [:debounce, :period], "yolo")

      assert_raise Inngest.DebounceConfigError, "invalid duration: 'yolo'", fn ->
        FnOpts.validate_debounce(opts, @config)
      end
    end

    test "should raise with period longer than 7 days" do
      opts = update_at(@fn_opts, [:debounce, :period], "8d")

      assert_raise Inngest.DebounceConfigError, fn ->
        FnOpts.validate_debounce(opts, @config)
      end
    end
  end

  describe "validate_batch_events/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      batch_events: %{
        max_size: 10,
        timeout: "5s"
      }
    }

    test "should succeed with valid config" do
      assert %{
               batchEvents: %{
                 maxSize: 10,
                 timeout: "5s"
               }
             } = FnOpts.validate_batch_events(@fn_opts, @config)
    end

    test "should raise if max_size is missing" do
      opts = drop_at(@fn_opts, [:batch_events, :max_size])

      assert_raise Inngest.BatchEventConfigError,
                   "'max_size' and 'timeout' must be set for batch_events",
                   fn ->
                     FnOpts.validate_batch_events(opts, @config)
                   end
    end

    test "should raise if timeout is missing" do
      opts = drop_at(@fn_opts, [:batch_events, :timeout])

      assert_raise Inngest.BatchEventConfigError,
                   "'max_size' and 'timeout' must be set for batch_events",
                   fn ->
                     FnOpts.validate_batch_events(opts, @config)
                   end
    end

    test "should raise if timeout is invalid" do
      opts = update_at(@fn_opts, [:batch_events, :timeout], "hello")

      assert_raise Inngest.BatchEventConfigError,
                   "invalid duration: 'hello'",
                   fn ->
                     FnOpts.validate_batch_events(opts, @config)
                   end
    end

    test "should raise if timeout is out of range" do
      opts = update_at(@fn_opts, [:batch_events, :timeout], "2m")

      assert_raise Inngest.BatchEventConfigError,
                   "'timeout' duration set to '2m', needs to be 1s - 60s",
                   fn ->
                     FnOpts.validate_batch_events(opts, @config)
                   end
    end
  end

  describe "validate_rate_limit/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      rate_limit: %{
        limit: 10,
        period: "5s"
      }
    }

    test "should succeed with valid config" do
      assert %{
               rateLimit: %{
                 limit: 10,
                 period: "5s"
               }
             } = FnOpts.validate_rate_limit(@fn_opts, @config)
    end

    test "should raise when limit is missing" do
      opts = drop_at(@fn_opts, [:rate_limit, :limit])

      assert_raise Inngest.RateLimitConfigError,
                   "'limit' and 'period' must be set for rate_limit",
                   fn ->
                     FnOpts.validate_rate_limit(opts, @config)
                   end
    end

    test "should raise when period is missing" do
      opts = drop_at(@fn_opts, [:rate_limit, :period])

      assert_raise Inngest.RateLimitConfigError,
                   "'limit' and 'period' must be set for rate_limit",
                   fn ->
                     FnOpts.validate_rate_limit(opts, @config)
                   end
    end

    test "should raise if timeout is out of range" do
      opts = update_at(@fn_opts, [:rate_limit, :period], "2m")

      assert_raise Inngest.RateLimitConfigError,
                   "'period' duration set to '2m', needs to be 1s - 60s",
                   fn ->
                     FnOpts.validate_rate_limit(opts, @config)
                   end
    end
  end

  describe "validate_concurrency/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      concurrency: %{
        limit: 2
      }
    }

    test "should succeed with valid config" do
      assert %{
               concurrency: %{
                 limit: 2
               }
             } = FnOpts.validate_concurrency(@fn_opts, @config)
    end
  end
end
