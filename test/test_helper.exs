ExUnit.start(exclude: [:skip])

ExUnit.after_suite(fn _ ->
  System.cmd("pkill", ["inngest-cli"])
end)
