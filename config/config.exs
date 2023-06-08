# General application configuration
import Config

config :inngest,
  event_base_url: "https://inn.gs",
  event_key: nil

config :tesla, adapter: {Tesla.Adapter.Hackney, [recv_timeout: 10_000]}

if config_env() == :dev do
  base_url = "http://127.0.0.1:8288"

  config :inngest,
    event_base_url: base_url,
    event_key: "test"
end
