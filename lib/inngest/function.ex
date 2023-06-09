defmodule Inngest.Function do
  @moduledoc false

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

  @spec from(map()) :: t()
  def from(
        %{
          "id" => id,
          "name" => name,
          "triggers" => triggers,
          "steps" => steps
        } = _data
      ) do
    %__MODULE__{
      id: id,
      name: name,
      triggers: triggers |> Enum.map(&Inngest.Function.Trigger.from/1),
      concurrency: 1,
      steps: steps
    }
  end
end

defmodule Inngest.Function.Trigger do
  @moduledoc false

  defstruct [
    :event,
    :expression,
    :cron
  ]

  @type t() :: %__MODULE__{
          event: map() | nil,
          expression: binary() | nil,
          cron: map() | nil
        }

  @spec from(map()) :: t()
  def from(%{"event" => event} = _data) do
    %__MODULE__{event: event}
  end

  def from(%{"cron" => cron} = _data) do
    %__MODULE__{cron: cron}
  end
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

defmodule Inngest.ServableFunction do
  @moduledoc false

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
  # TODO: Provide proper types for triggers
  @callback trigger() :: any()

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
end
