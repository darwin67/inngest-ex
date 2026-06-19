defmodule Inngest.FnOptsTest do
  use ExUnit.Case, async: true

  alias Inngest.FnOpts

  @config %{}
  @partial_duration_inputs [
    "1ms",
    "5m later",
    "5minutes",
    "1s2",
    "0.5s",
    "duration 1m",
    " 1m",
    "1m ",
    "1m\n",
    "1h/30m",
    "1d2h"
  ]

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
        key: "event.data.account_id",
        period: "5s",
        timeout: "30s"
      }
    }

    test "should succeed with valid config" do
      assert %{
               debounce: %{
                 key: "event.data.account_id",
                 period: "5s",
                 timeout: "30s"
               }
             } = FnOpts.validate_debounce(@fn_opts, @config)
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

    test "should raise with invalid timeout" do
      opts = update_at(@fn_opts, [:debounce, :timeout], "yolo")

      assert_raise Inngest.DebounceConfigError, "invalid duration: 'yolo'", fn ->
        FnOpts.validate_debounce(opts, @config)
      end
    end

    @partial_duration_inputs
    |> Enum.each(fn duration ->
      test "should raise when timeout is partial duration #{inspect(duration)}" do
        opts = update_at(@fn_opts, [:debounce, :timeout], unquote(duration))

        assert_raise Inngest.DebounceConfigError,
                     "invalid duration: '#{unquote(duration)}'",
                     fn ->
                       FnOpts.validate_debounce(opts, @config)
                     end
      end
    end)
  end

  describe "validate_priority/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "FooBar",
      priority: %{run: "event.data.priority"}
    }

    test "should succeed with valid config" do
      assert %{
               priority: %{run: "event.data.priority"}
             } = FnOpts.validate_priority(@fn_opts, @config)
    end

    test "should raise with invalid config" do
      opts = %{@fn_opts | priority: "hello"}

      assert_raise Inngest.PriorityConfigError, "invalid priority config: 'hello'", fn ->
        FnOpts.validate_priority(opts, @config)
      end
    end

    test "should raise if priority run is not a string" do
      opts = update_at(@fn_opts, [:priority, :run], 10)

      assert_raise Inngest.PriorityConfigError, "invalid priority run: '10'", fn ->
        FnOpts.validate_priority(opts, @config)
      end
    end
  end

  describe "validate_batch_events/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      batch_events: %{
        max_size: 10,
        timeout: "5s",
        key: "event.data.account_id"
      }
    }

    test "should succeed with valid config" do
      assert %{
               batchEvents: %{
                 maxSize: 10,
                 timeout: "5s",
                 key: "event.data.account_id"
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

    test "should raise if rate limit is set with batching" do
      opts = Map.put(@fn_opts, :rate_limit, %{limit: 1, period: "10m"})

      assert_raise Inngest.BatchEventConfigError,
                   "'rate_limit' cannot be used with event_batches",
                   fn ->
                     FnOpts.validate_batch_events(opts, @config)
                   end
    end

    test "should raise if cancel_on is set with batching" do
      opts = Map.put(@fn_opts, :cancel_on, %{event: "hello"})

      assert_raise Inngest.BatchEventConfigError,
                   "'cancel_on' cannot be used with event_batches",
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

  describe "validate_throttle/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      throttle: %{
        key: "event.data.account_id",
        limit: 10,
        period: "1m",
        burst: 3
      }
    }

    test "should succeed with valid config" do
      assert %{
               throttle: %{
                 key: "event.data.account_id",
                 limit: 10,
                 period: "1m",
                 burst: 3
               }
             } = FnOpts.validate_throttle(@fn_opts, @config)
    end

    test "should raise when limit is missing" do
      opts = drop_at(@fn_opts, [:throttle, :limit])

      assert_raise Inngest.ThrottleConfigError,
                   "'limit' and 'period' must be set for throttle",
                   fn ->
                     FnOpts.validate_throttle(opts, @config)
                   end
    end

    test "should raise when period is missing" do
      opts = drop_at(@fn_opts, [:throttle, :period])

      assert_raise Inngest.ThrottleConfigError,
                   "'limit' and 'period' must be set for throttle",
                   fn ->
                     FnOpts.validate_throttle(opts, @config)
                   end
    end

    test "should raise when period is invalid" do
      opts = update_at(@fn_opts, [:throttle, :period], "yolo")

      assert_raise Inngest.ThrottleConfigError, "invalid duration: 'yolo'", fn ->
        FnOpts.validate_throttle(opts, @config)
      end
    end

    @partial_duration_inputs
    |> Enum.each(fn duration ->
      test "should raise when period is partial duration #{inspect(duration)}" do
        opts = update_at(@fn_opts, [:throttle, :period], unquote(duration))

        assert_raise Inngest.ThrottleConfigError,
                     "invalid duration: '#{unquote(duration)}'",
                     fn ->
                       FnOpts.validate_throttle(opts, @config)
                     end
      end
    end)
  end

  describe "validate_singleton/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      singleton: %{
        key: "event.data.account_id",
        mode: :skip
      }
    }

    test "should succeed with valid config" do
      assert %{
               singleton: %{
                 key: "event.data.account_id",
                 mode: "skip"
               }
             } = FnOpts.validate_singleton(@fn_opts, @config)
    end

    test "should succeed with cancel mode" do
      opts = update_at(@fn_opts, [:singleton, :mode], :cancel)

      assert %{
               singleton: %{
                 key: "event.data.account_id",
                 mode: "cancel"
               }
             } = FnOpts.validate_singleton(opts, @config)
    end

    test "should raise when mode is missing" do
      opts = drop_at(@fn_opts, [:singleton, :mode])

      assert_raise Inngest.SingletonConfigError,
                   "'mode' must be set for singleton",
                   fn ->
                     FnOpts.validate_singleton(opts, @config)
                   end
    end

    test "should raise when mode is invalid" do
      opts = update_at(@fn_opts, [:singleton, :mode], "replace")

      assert_raise Inngest.SingletonConfigError,
                   "invalid mode '\"replace\"', needs to be :skip|:cancel",
                   fn ->
                     FnOpts.validate_singleton(opts, @config)
                   end
    end

    test "should raise when mode is a string value" do
      opts = update_at(@fn_opts, [:singleton, :mode], "skip")

      assert_raise Inngest.SingletonConfigError,
                   "invalid mode '\"skip\"', needs to be :skip|:cancel",
                   fn ->
                     FnOpts.validate_singleton(opts, @config)
                   end
    end
  end

  describe "validate_timeouts/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      timeouts: %{
        start: "1m",
        finish: "1h"
      }
    }

    test "should succeed with valid config" do
      assert %{
               timeouts: %{
                 start: "1m",
                 finish: "1h"
               }
             } = FnOpts.validate_timeouts(@fn_opts, @config)
    end

    test "should succeed when only start is set" do
      opts = %{@fn_opts | timeouts: %{start: "1m"}}

      assert %{
               timeouts: %{
                 start: "1m"
               }
             } = FnOpts.validate_timeouts(opts, @config)
    end

    test "should raise when start is invalid" do
      opts = update_at(@fn_opts, [:timeouts, :start], "yolo")

      assert_raise Inngest.TimeoutConfigError, "invalid duration: 'yolo'", fn ->
        FnOpts.validate_timeouts(opts, @config)
      end
    end

    test "should raise when finish is invalid" do
      opts = update_at(@fn_opts, [:timeouts, :finish], "yolo")

      assert_raise Inngest.TimeoutConfigError, "invalid duration: 'yolo'", fn ->
        FnOpts.validate_timeouts(opts, @config)
      end
    end

    @partial_duration_inputs
    |> Enum.each(fn duration ->
      test "should raise when start is partial duration #{inspect(duration)}" do
        opts = update_at(@fn_opts, [:timeouts, :start], unquote(duration))

        assert_raise Inngest.TimeoutConfigError,
                     "invalid duration: '#{unquote(duration)}'",
                     fn ->
                       FnOpts.validate_timeouts(opts, @config)
                     end
      end

      test "should raise when finish is partial duration #{inspect(duration)}" do
        opts = update_at(@fn_opts, [:timeouts, :finish], unquote(duration))

        assert_raise Inngest.TimeoutConfigError,
                     "invalid duration: '#{unquote(duration)}'",
                     fn ->
                       FnOpts.validate_timeouts(opts, @config)
                     end
      end
    end)
  end

  describe "validate_idempotency/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      idempotency: "event.data.foobar"
    }

    test "should succeed with valid settings" do
      assert %{
               idempotency: "event.data.foobar"
             } = FnOpts.validate_idempotency(@fn_opts, @config)
    end

    test "should raise if value is not string" do
      opts = %{@fn_opts | idempotency: false}

      assert_raise Inngest.IdempotencyConfigError,
                   "idempotency must be a CEL string",
                   fn ->
                     FnOpts.validate_idempotency(opts, @config)
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

    test "should succeed with just number" do
      opts = %{@fn_opts | concurrency: 10}

      assert %{
               concurrency: 10
             } = FnOpts.validate_concurrency(opts, @config)
    end

    test "should succeed with valid settings" do
      assert %{
               concurrency: %{
                 limit: 2
               }
             } = FnOpts.validate_concurrency(@fn_opts, @config)
    end

    test "should succeed with multiple settings" do
      opts = %{@fn_opts | concurrency: [%{limit: 2, scope: "fn"}, %{limit: 10, scope: "account"}]}

      assert %{
               concurrency: [
                 %{limit: 2, scope: "fn"},
                 %{limit: 10, scope: "account"}
               ]
             } = FnOpts.validate_concurrency(opts, @config)
    end

    test "should raise when limit is missing" do
      opts = drop_at(@fn_opts, [:concurrency, :limit])

      assert_raise Inngest.ConcurrencyConfigError,
                   "'limit' must be set for concurrency",
                   fn ->
                     FnOpts.validate_concurrency(opts, @config)
                   end
    end

    test "should raise if scope is invalid" do
      opts = %{@fn_opts | concurrency: %{limit: 2, scope: "hello"}}

      assert_raise Inngest.ConcurrencyConfigError,
                   "invalid scope 'hello', needs to be \"fn\"|\"env\"|\"account\"",
                   fn ->
                     FnOpts.validate_concurrency(opts, @config)
                   end
    end

    test "should raise if provided invalid setting" do
      opts = %{@fn_opts | concurrency: "foobar"}

      assert_raise Inngest.ConcurrencyConfigError,
                   "invalid concurrency setting",
                   fn ->
                     FnOpts.validate_concurrency(opts, @config)
                   end
    end
  end

  describe "validate_cancel_on/2" do
    @fn_opts %FnOpts{
      id: "foobar",
      name: "Foobar",
      cancel_on: %{
        event: "test/cancel"
      }
    }

    test "should succeed with single setting" do
      assert %{
               cancel: [
                 %{event: "test/cancel"}
               ]
             } = FnOpts.validate_cancel_on(@fn_opts, @config)
    end

    test "should succeed with list of cancels" do
      cancel = [
        %{event: "test/cancel"},
        %{event: "helloworld"}
      ]

      opts = %{@fn_opts | cancel_on: cancel}

      assert %{
               cancel: [
                 %{event: "test/cancel"},
                 %{event: "helloworld"}
               ]
             } = FnOpts.validate_cancel_on(opts, @config)
    end

    test "should raise if event is missing" do
      opts = %{@fn_opts | cancel_on: %{}}

      assert_raise Inngest.CancelConfigError,
                   "'event' must be set for cancel_on",
                   fn ->
                     FnOpts.validate_cancel_on(opts, @config)
                   end
    end

    test "should raise if timeout is invalid duration" do
      opts = %{@fn_opts | cancel_on: %{event: "test/cancel", timeout: "hello"}}

      assert_raise Inngest.CancelConfigError,
                   "invalid duration: 'hello'",
                   fn ->
                     FnOpts.validate_cancel_on(opts, @config)
                   end
    end

    test "should raise if there are > 5 cancellation triggers" do
      cancel = [
        %{event: "test/cancel"},
        %{event: "helloworld"},
        %{event: "foobar"},
        %{event: "yolo"},
        %{event: "inngest"},
        %{event: "something"}
      ]

      opts = %{@fn_opts | cancel_on: cancel}

      assert_raise Inngest.CancelConfigError,
                   "cannot have more than 5 cancellation triggers",
                   fn ->
                     FnOpts.validate_cancel_on(opts, @config)
                   end
    end

    test "should raise with invalid config" do
      opts = %{@fn_opts | cancel_on: "hello"}

      assert_raise Inngest.CancelConfigError,
                   "invalid cancellation config: 'hello'",
                   fn ->
                     FnOpts.validate_cancel_on(opts, @config)
                   end
    end
  end
end
