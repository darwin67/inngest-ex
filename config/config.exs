# General application configuration
import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

config :inngest,
  env: :dev
