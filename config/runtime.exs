import Config
config :job_processor, port: String.to_integer(System.get_env("PORT", "4000"))
