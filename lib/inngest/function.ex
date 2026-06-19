defmodule Inngest.Function do
  @moduledoc """
  Module to be used within user code to setup an Inngest function.
  Making it servable and invokable.

  Creating an Inngest function is as easy as using `Inngest.Function`. It creates
  the necessary attributes and handlers it needs to work with Inngest.

      defmodule MyApp.Inngest.SomeJob do
        use Inngest.Function
        alias Inngest.{FnOpts, Trigger}

        @func %FnOpts{id: "my-func", name: "some job"}
        @trigger %Trigger{event: "job/foobar"}

        @impl true
        def exec(ctx, input) do
          {:ok, "hello world"}
        end

        # Optional handler to handle failures when the function fails
        # after all retries are exhausted.
        def handle_failure(ctx, %{step: step} = _args) do
          _ = step.run(ctx, "handle-failure", fn ->
            "Do something here"
          end)

          {:ok, "error handled"}
        end
      end

  ## Function Options

  Assign `Inngest.FnOpts` to `@func` to configure the function. See `Inngest.FnOpts`
  to see what options are available.

  ## Trigger

  A trigger is causes a function to run. One of the following is required, and
  they're mutually exclusive.

  #### `event` - `string` and/or `expression` - `string`

  The name of the event that will trigger this event to run.
  We recommend it to name it with a prefix so it's a easier pattern to identify
  what it's for.

  e.g. `auth/signup.email.send`

  #### `cron` - `string`

  A [unix-cron](https://crontab.guru/) compatible schedule string.

  Optional timezone prefix, e.g. `TZ=Europe/Paris 0 12 * * 5`.
  """
  alias Inngest.{Config, Trigger}
  alias Inngest.Function.{Context, Input}

  @doc """
  Returns the function's human-readable ID, such as "sign-up-flow"
  """
  @callback slug() :: String.t()

  @doc """
  Returns the function name
  """
  @callback name() :: String.t()

  @doc """
  Returns the event name or schedule that triggers the function
  """
  @callback trigger() :: Trigger.t()

  @doc """
  The method to be called when the Inngest function starts execution.

  Only this method needs to be provided.
  """
  @callback exec(Context.t(), Input.t()) :: {:ok, any()} | {:error, any()}

  defmacro __using__(_opts) do
    quote location: :keep do
      alias Inngest.{Client, FnOpts, Trigger}

      Enum.each(
        [:func, :trigger],
        &Module.register_attribute(__MODULE__, &1, persist: true)
      )

      @behaviour Inngest.Function

      @impl true
      def slug() do
        slug(Config.app_name())
      end

      def slug(app_id) do
        fnid = fn_opts() |> Map.get(:id)
        Inngest.Util.slugify(app_id <> "-" <> fnid)
      end

      @impl true
      def name() do
        case fn_opts() |> Map.get(:name) do
          nil -> slug()
          name -> name
        end
      end

      @impl true
      def trigger() do
        __MODULE__.__info__(:attributes)
        |> Keyword.get(:trigger)
        |> List.first()
      end

      def slugs() do
        failure = if failure_handler_defined?(), do: [failure_slug()], else: []
        [slug()] ++ failure
      end

      def slugs(app_id) do
        failure = if failure_handler_defined?(), do: [failure_slug(app_id)], else: []
        [slug(app_id)] ++ failure
      end

      def serve(path) do
        serve(path, Config.app_name())
      end

      def serve(path, app_id) do
        serve(path, app_id, Config.serve_url(path))
      end

      def serve(_path, app_id, serve_url) do
        handler =
          if failure_handler_defined?() do
            id = failure_slug(app_id)

            [
              %{
                id: id,
                name: "#{name()} (failure)",
                triggers: [
                  %Trigger{
                    event: "inngest/function.failed",
                    expression: "event.data.function_id == \"#{slug(app_id)}\""
                  }
                ],
                steps: %{
                  step: %Inngest.Function.Step{
                    id: :step,
                    name: "step",
                    runtime: %{
                      type: "http",
                      url: "#{serve_url}?stepId=step&fnId=#{id}"
                    },
                    retries: %{
                      attempts: 0
                    }
                  }
                }
              }
            ]
          else
            []
          end

        [
          %{
            id: slug(app_id),
            name: name(),
            triggers: [trigger()],
            steps: %{
              step: %Inngest.Function.Step{
                id: :step,
                name: "step",
                runtime: %{
                  type: "http",
                  url: "#{serve_url}?stepId=step&fnId=#{slug(app_id)}"
                },
                retries: %{
                  attempts: retries()
                }
              }
            }
          }
          |> maybe_debounce()
          |> maybe_priority()
          |> maybe_batch_events()
          |> maybe_rate_limit()
          |> maybe_throttle()
          |> maybe_singleton()
          |> maybe_timeouts()
          |> maybe_idempotency()
          |> maybe_concurrency()
          |> maybe_cancel_on()
        ] ++ handler
      end

      defp retries(), do: fn_opts() |> Map.get(:retries)

      defp maybe_debounce(config),
        do: fn_opts() |> Inngest.FnOpts.validate_debounce(config)

      defp maybe_priority(config),
        do: fn_opts() |> Inngest.FnOpts.validate_priority(config)

      defp maybe_batch_events(config),
        do: fn_opts() |> Inngest.FnOpts.validate_batch_events(config)

      defp maybe_rate_limit(config),
        do: fn_opts() |> Inngest.FnOpts.validate_rate_limit(config)

      defp maybe_throttle(config),
        do: fn_opts() |> Inngest.FnOpts.validate_throttle(config)

      defp maybe_singleton(config),
        do: fn_opts() |> Inngest.FnOpts.validate_singleton(config)

      defp maybe_timeouts(config),
        do: fn_opts() |> Inngest.FnOpts.validate_timeouts(config)

      defp maybe_idempotency(config),
        do: fn_opts() |> Inngest.FnOpts.validate_idempotency(config)

      defp maybe_concurrency(config),
        do: fn_opts() |> Inngest.FnOpts.validate_concurrency(config)

      defp maybe_cancel_on(config),
        do: fn_opts() |> Inngest.FnOpts.validate_cancel_on(config)

      defp fn_opts() do
        case __MODULE__.__info__(:attributes) |> Keyword.get(:func) |> List.first() do
          nil -> %Inngest.FnOpts{}
          val -> val
        end
      end

      defp failure_handler_defined?() do
        __MODULE__.__info__(:functions) |> Keyword.get(:handle_failure) == 2
      end

      defp failure_slug(), do: "#{slug()}-failure"
      defp failure_slug(app_id), do: "#{slug(app_id)}-failure"
    end
  end

  @doc false
  @spec validate_datetime(any()) :: {:ok, binary()} | {:error, binary()}
  def validate_datetime(%DateTime{} = datetime),
    do: Timex.format(datetime, "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}Z")

  # TODO:
  # def validate_datetime(%Date{} = date), do: nil

  def validate_datetime(datetime) when is_binary(datetime) do
    with {:error, _} <- Timex.parse(datetime, "{RFC3339}"),
         {:error, _} <- Timex.parse(datetime, "{YYYY}-{MM}-{DD}T{h24}:{mm}:{ss}"),
         {:error, _} <- Timex.parse(datetime, "{RFC1123}"),
         {:error, _} <- Timex.parse(datetime, "{RFC822}"),
         {:error, _} <- Timex.parse(datetime, "{RFC822z}"),
         # "Monday, 02-Jan-06 15:04:05 MST"
         {:error, _} <- Timex.parse(datetime, "{WDfull}, {D}-{Mshort}-{YY} {ISOtime} {Zname}"),
         # "Mon Jan 02 15:04:05 -0700 2006"
         {:error, _} <- Timex.parse(datetime, "{WDshort} {Mshort} {DD} {ISOtime} {Z} {YYYY}"),
         {:error, _} <- Timex.parse(datetime, "{UNIX}"),
         {:error, _} <- Timex.parse(datetime, "{ANSIC}"),
         # "Jan _2 15:04:05"
         # "Jan _2 15:04:05.000"
         {:error, _} <- Timex.parse(datetime, "{Mshort} {_D} {ISOtime}"),
         # {:error, _} <- Timex.parse(datetime, "{Mshort} {_D} {ISOtime}"),
         {:error, _} <- Timex.parse(datetime, "{ISOdate}") do
      {:error, "Unknown format for DateTime"}
    else
      {:ok, _val} ->
        {:ok, datetime}
    end
  end

  def validate_datetime(_), do: {:error, "Expect valid DateTime formatted input"}
end
