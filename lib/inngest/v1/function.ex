defmodule Inngest.V1.Function do
  @moduledoc """
  Module to be used within user code to setup an Inngest function.
  Making it servable and invokable.
  """

  defmacro __using__(opts) do
    quote do
      def serve() do
        [name: name, event: event] = unquote(opts)

        %{
          id: name |> String.replace("/", "-") |> String.replace(".", "-"),
          name: name,
          triggers: [
            %{event: event}
          ],
          concurrency: 10,
          steps: %{
            dummy: %{
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
end
