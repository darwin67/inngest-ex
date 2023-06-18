# General application configuration
import Config

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

config :inngest,
  env: :dev
