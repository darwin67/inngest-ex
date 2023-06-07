# General application configuration
import Config

config :inngest,
  event_base_url: "https://inn.gs",
  event_key: nil

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

import_config "#{config_env()}.exs"
