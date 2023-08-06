# General application configuration
import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

config :inngest,
  # app_host: "https://79c9-99-123-3-121.ngrok-free.app",
  # path_runtime_eval: true,
  # signing_key: "",
  # event_key: ""
  env: :dev
