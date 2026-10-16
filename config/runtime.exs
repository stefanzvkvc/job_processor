import Config

config :job_processor,
  port: String.to_integer(System.get_env("PORT", "4000")),
  # Tests call the router directly with Plug.Test, so they don't need the
  # HTTP server. Skipping it lets `mix test` run while the app is running.
  server: config_env() != :test
