opts = [:skip]
opts = opts ++ if System.get_env("UNIT") == "true", do: [:integration], else: []

{:ok, _} = Inngest.Test.Application.start(:normal, [])

ExUnit.start(exclude: opts)

ExUnit.after_suite(fn _ ->
  System.cmd("pkill", ["inngest-cli"])
end)
