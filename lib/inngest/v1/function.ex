defmodule Inngest.V1.Function do
  alias Inngest.Config
  alias Inngest.Function.Trigger

  @callback slug() :: binary()

  @callback name() :: binary()

  @callback trigger() :: Trigger.t()

  defmacro __using__(_opts) do
    quote location: :keep do
      alias Inngest.Client
      alias Inngest.Function.{Trigger, Step}

      Enum.each(
        [:func, :trigger],
        &Module.register_attribute(__MODULE__, &1, persist: true)
      )

      @behaviour Inngest.V1.Function

      @impl true
      def slug() do
        __MODULE__.__info__(:attributes)
        |> Keyword.get(:func)
        |> List.first()
        |> Map.get(:id)
      end

      @impl true
      def name() do
        case __MODULE__.__info__(:attributes)
             |> Keyword.get(:func)
             |> List.first()
             |> Map.get(:name) do
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

      def step(path),
        do: %{
          step: %Step{
            id: :step,
            name: "step",
            runtime: %Step.RunTime{
              url: "#{Config.app_host() <> path}?fnId=#{slug()}&step=step"
            },
            retries: %Step.Retry{}
          }
        }

      def serve(path) do
        %{
          id: slug(),
          name: name(),
          triggers: [trigger()],
          steps: step(path),
          mod: __MODULE__
        }
      end
    end
  end
end

defmodule Inngest.Function.Opts do
  defstruct [
    :id,
    :name,
    :retries
  ]

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          retries: number()
        }
end
