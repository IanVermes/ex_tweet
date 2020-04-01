# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configure the magic numbers involved in retrying HTTP requests
config :ex_tweet, :request_settings,
  max_reattempts: 10,
  max_timeout_ms: 30_000,
  # Wait longer than a minute before hitting twitter a gain
  reattempt_sleep_ms: 61_000

# Configures Elixir's Logger
config :logger, :console, format: "$time $metadata[$level] $message\n"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
