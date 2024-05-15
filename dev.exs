require Logger

Task.async(fn ->
  {:ok, _pid} = Inngest.Test.Application.start(:normal, [])
  Logger.debug("Starting SDK development server")

  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
