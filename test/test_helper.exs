opts = [:skip]
opts = opts ++ if System.get_env("UNIT") == "true", do: [:integration], else: []

ExUnit.start(exclude: opts)

ExUnit.after_suite(fn _ ->
  System.cmd("pkill", ["inngest-cli"])
end)
