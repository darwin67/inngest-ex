# General application configuration
import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

config :inngest,
  # app_host: "https://79c9-99-123-3-121.ngrok-free.app",
  # signing_key: "",
  # event_key: ""
  path_runtime_eval: true,
  env: :dev

config :logger, :console,
  level: :debug,
  colors: [enabled: true]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
