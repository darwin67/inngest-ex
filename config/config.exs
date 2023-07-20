# General application configuration
import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

config :inngest,
  env: :dev,
  signing_key: "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
