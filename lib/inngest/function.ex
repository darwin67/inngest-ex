defmodule Inngest.FunctionOpts do
  @moduledoc false

  defstruct [
    :name,
    :id,
    :concurrency,
    :idempotency,
    :retries
  ]

  @type t() :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          concurrency: number(),
          idempotency: String.t(),
          retries: number()
        }
end

defmodule Inngest.Function do
  @moduledoc """
  Module to be used within user code to setup an Inngest function.
  Making it servable and invokable.
  """

  @doc """
  Returns the function's human-readable ID, such as "sign-up-flow"
  """
  @callback slug() :: String.t()

  @doc """
  Returns the function name
  """
  @callback name() :: String.t()

  @doc """
  Returns the function's configs
  """
  @callback config() :: Inngest.FunctionOpts.t()

  @doc """
  Returns the event name or schedule that triggers the function
  """
  @callback trigger() :: Inngest.Function.Trigger.t()

  @doc """
  Returns the zero event type to marshal the event into, given an
  event name
  """
  @callback zero_event() :: any()

  @doc """
  Returns the SDK function to call. This must alawys be of type SDKFunction,
  but has an any type as we register many functions of different types into a
  type-agnostic handler; this is a generic implementation detail, unfortunately.
  """
  @callback func() :: any()

  defmacro __using__(opts) do
    quote location: :keep do
      alias Inngest.Function.Trigger
      @behaviour Inngest.Function

      @opts unquote(opts)

      @impl true
      def slug() do
        if Keyword.get(@opts, :id),
          do: Keyword.get(@opts, :id),
          else:
            Keyword.get(@opts, :name)
            |> String.replace(~r/[\.\/\s]+/, "-")
            |> String.downcase()
      end

      @impl true
      def name(), do: Keyword.get(@opts, :name)

      @impl true
      def config(), do: %Inngest.FunctionOpts{}

      @impl true
      def trigger(), do: @opts |> Map.new() |> trigger()
      defp trigger(%{event: event} = _opts), do: %Trigger{event: event}
      defp trigger(%{cron: cron} = _opts), do: %Trigger{cron: cron}

      @impl true
      def zero_event(), do: "placeholder"

      @impl true
      def func(), do: "placeholder"

      def serve() do
        %{
          id: slug(),
          name: name(),
          triggers: [trigger()],
          steps: %{
            "dummy-step" => %{
              id: "dummy-step",
              name: "dummy step",
              runtime: %{
                type: "http",
                url: "http://127.0.0.1:4000/api/inngest"
              },
              retries: %{
                attempts: 1
              }
            }
          }
        }
      end
    end
  end

  defstruct [
    :id,
    :name,
    :triggers,
    :concurrency,
    :steps
  ]

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          triggers: [any()],
          concurrency: number(),
          steps: map()
        }
end

defmodule Inngest.Function.Step do
  @moduledoc false

  defstruct [
    :id,
    :name,
    :path,
    :retries,
    :runtime
  ]
end
