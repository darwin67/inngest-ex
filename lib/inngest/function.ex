defmodule Inngest.Function do
  @moduledoc """
  Module to be used within user code to setup an Inngest function.
  Making it servable and invokable.
  """
  alias Inngest.Function.Args

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
  @callback trigger() :: Inngest.Function.Trigger.t()

  @doc """
  The user provided logic that will be invoked
  """
  @callback perform(Args.t()) :: {:ok, any()} | {:error, any()}

  defmacro __using__(opts) do
    quote location: :keep do
      alias Inngest.Function.Trigger
      @behaviour Inngest.Function

      @opts unquote(opts)

      @impl true
      def slug() do
        # TOOD: Use app name as prefix
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
      def trigger(), do: @opts |> Map.new() |> trigger()
      defp trigger(%{event: event} = _opts), do: %Trigger{event: event}
      defp trigger(%{cron: cron} = _opts), do: %Trigger{cron: cron}

      def steps(),
        do: %{
          "step" => %{
            id: "step",
            name: "step",
            runtime: %{
              type: "http",
              url: "http://127.0.0.1:4000/api/inngest?fnId=#{slug()}&step=step"
            },
            retries: %{
              attempts: 3
            }
          }
        }

      def serve() do
        %{
          id: slug(),
          name: name(),
          triggers: [trigger()],
          steps: steps(),
          mod: __MODULE__
        }
      end
    end
  end

  # TODO: This is required for the local dev UI
  # Implement it when addressing that.
  def from(_) do
    %{}
  end
end
